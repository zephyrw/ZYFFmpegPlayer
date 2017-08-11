//
//  ZYDecoder.m
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/10.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import "ZYDecoder.h"
#import "avformat.h"
#import "ZYVideoDecoder.h"
#import "ZYAudioDecoder.h"

@interface ZYDecoder()

{
    AVFormatContext *_format_context;
}

@property (copy, nonatomic) NSString *filePath;
@property (strong, nonatomic) NSDictionary *metadata;
@property (strong, nonatomic) NSMutableDictionary *formatContextOptions;
@property (strong, nonatomic) NSMutableDictionary *codecContextOptions;
@property (assign, nonatomic) BOOL videoEnable;
@property (assign, nonatomic) BOOL audioEnable;
@property (assign, nonatomic) BOOL reading;
@property (strong, nonatomic) ZYVideoDecoder *videoDecoder;
@property (strong, nonatomic) ZYAudioDecoder *audioDecoder;
@property (strong, nonatomic) NSOperationQueue *operationQueue;
@property (strong, nonatomic) NSInvocationOperation *openFileOperation;
@property (strong, nonatomic) NSInvocationOperation *readPacketOperation;
@property (strong, nonatomic) NSInvocationOperation *decodeFrameOperation;

@end

@implementation ZYDecoder

static const int max_packet_buffer_size = 15 * 1024 * 1024;
static NSTimeInterval max_packet_sleep_full_time_interval = 0.1;
//static NSTimeInterval max_packet_sleep_full_and_pause_time_interval = 0.5;

+ (instancetype)decoderWithVideoURL:(NSURL *)videoURL {
    
    return [[self alloc] initWithVideoURL:videoURL];
    
}

- (instancetype)initWithVideoURL:(NSURL *)videoURL {
    
    if (self = [super init]) {
        if ([videoURL isFileURL]) {
            self.filePath = videoURL.path;
        } else {
            self.filePath = videoURL.absoluteString;
        }
        
        [self open];
    }
    return self;
    
}

- (void)open {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        av_register_all();
        avformat_network_init();
        avcodec_register_all();
    });
    
    self.operationQueue = [[NSOperationQueue alloc] init];
    self.operationQueue.maxConcurrentOperationCount = 2;
    self.operationQueue.qualityOfService = NSQualityOfServiceUserInitiated;
    
    self.openFileOperation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(openFile) object:nil];
    self.openFileOperation.queuePriority = NSOperationQueuePriorityVeryHigh;
    self.openFileOperation.qualityOfService = NSQualityOfServiceUserInitiated;
    [self.operationQueue addOperation:self.openFileOperation];
    
}

- (void)openFile {
    
    _format_context = avformat_alloc_context();
    
    int result = -1;
    
    result = avformat_open_input(&_format_context, self.filePath.UTF8String, NULL, NULL);
    if (result) {
        NSLog(@"Failed to open input");
        if (_format_context) {
            avformat_free_context(_format_context);
        }
        return;
    }
    
    result = avformat_find_stream_info(_format_context, NULL);
    if (result) {
        NSLog(@"Failed to find stream info!");
        if (_format_context) {
            avformat_close_input(&_format_context);
        }
        return;
    }
    
    [self findStreamWithMediaType:AVMEDIA_TYPE_VIDEO];
    [self findStreamWithMediaType:AVMEDIA_TYPE_AUDIO];
    
    if (!self.videoEnable && !self.audioEnable) {
        NSLog(@"Neither of audio or video stream is valid!");
        return;
    }
    
    NSLog(@"---------------Media Info------------------");
    av_dump_format(_format_context, 0, _filePath.UTF8String, 0);
    NSLog(@"-------------------------------------------");
    
    if ([self.delegate respondsToSelector:@selector(decoderDidPrepareToDecodeFrames)]) {
        [self.delegate decoderDidPrepareToDecodeFrames];
    }
    
    [self setupReadPacketOperation];
    
}

- (void)setupReadPacketOperation {
    
    if (!self.readPacketOperation || self.readPacketOperation.isFinished) {
        self.readPacketOperation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(readPacket) object:nil];
        self.readPacketOperation.queuePriority = NSOperationQueuePriorityVeryHigh;
        self.readPacketOperation.qualityOfService = NSQualityOfServiceUserInitiated;
        [self.openFileOperation addDependency:self.openFileOperation];
        [self.operationQueue addOperation:self.readPacketOperation];
    }
    
    if (self.videoEnable && (!self.decodeFrameOperation || self.decodeFrameOperation.isFinished)) {
        self.decodeFrameOperation = [[NSInvocationOperation alloc] initWithTarget:self.videoDecoder selector:@selector(startDecodeThread) object:nil];
        self.decodeFrameOperation.queuePriority = NSOperationQueuePriorityVeryHigh;
        self.decodeFrameOperation.qualityOfService = NSQualityOfServiceUserInitiated;
        [self.decodeFrameOperation addDependency:self.openFileOperation];
        [self.operationQueue addOperation:self.decodeFrameOperation];
    }
    
}


- (void)findStreamWithMediaType:(int)mediaType {
    
    AVCodec *codec;
    
    NSString *mediaTypeStr = mediaType == AVMEDIA_TYPE_VIDEO ? @"video" : @"audio";
    
    int streamIndex = av_find_best_stream(_format_context, mediaType, -1, -1, &codec, 0);
    
    if (streamIndex < 0) {
        NSLog(@"Failed to find stream: %@!", mediaTypeStr);
        return;
    }
    
    AVStream *stream = _format_context->streams[streamIndex];
    
    AVCodecContext *codecContext = avcodec_alloc_context3(codec);
    if (!codecContext) {
        NSLog(@"Failed to create %@ codec context!", mediaTypeStr);
        return;
    }
    
    avcodec_parameters_to_context(codecContext, stream->codecpar);
    av_codec_set_pkt_timebase(codecContext, stream->time_base);
    
    int result = avcodec_open2(codecContext, codec, NULL);
    if (result) {
        NSLog(@"Failed to open avcodec!");
        avcodec_free_context(&codecContext);
        return;
    }
    
    double timeBase, fps;
    
    if (stream->time_base.den > 0 && stream->time_base.num > 0) {
        timeBase = av_q2d(codecContext->time_base);
    } else {
        timeBase = mediaType == AVMEDIA_TYPE_VIDEO ? 0.00004 : 0.000025;
    }
    
    if (stream->avg_frame_rate.den > 0 && stream->avg_frame_rate.num) {
        fps = av_q2d(stream->avg_frame_rate);
    } else if (stream->r_frame_rate.den > 0 && stream->r_frame_rate.num) {
        fps = av_q2d(stream->r_frame_rate);
    } else {
        fps = 1.0 / timeBase;
    }
    
    if (mediaType == AVMEDIA_TYPE_VIDEO) {
        self.videoDecoder = [ZYVideoDecoder videoDecoderWithCodecContext:codecContext timeBase:timeBase fps:fps];
        self.videoEnable = YES;
        self.videoDecoder.streamIndex = streamIndex;
    } else {
        self.audioDecoder = [ZYAudioDecoder audioDecoderWithCodecContext:codecContext timeBase:timeBase];
        self.audioEnable = YES;
        self.audioDecoder.streamIndex = streamIndex;
    }
}

- (void)readPacket {
    
    AVPacket packet;
    
    BOOL isFinished = NO;
    while (!isFinished) {
        
        if (self.videoDecoder.packetSize + self.audioDecoder.size >= max_packet_buffer_size) {
            NSTimeInterval interval = 0;
//            if (self.paused) {
//                interval = max_packet_sleep_full_and_pause_time_interval;
//            } else {
            interval = max_packet_sleep_full_time_interval;
//            }
            NSLog(@"read thread sleep : %f", interval);
            [NSThread sleepForTimeInterval:interval];
            continue;
        }
        
        int result = av_read_frame(_format_context, &packet);
        if (result) {
            NSLog(@"Finish to read frame!");
            break;
        }
        
        if (self.videoEnable && packet.stream_index == self.videoDecoder.streamIndex) {
            
            [self.videoDecoder savePacket:packet];
            
        }else if (self.audioEnable && packet.stream_index == self.audioDecoder.streamIndex) {
            
            [self.audioDecoder decodePacket:packet];
            
        }
        
        
    }
    
}

- (ZYVideoFrame *)getFrameAsync {
    if (self.videoDecoder) {
        return [self.videoDecoder getFrameAsync];
    }
    return nil;
}

- (void)closeFile {
    
    if (self.videoDecoder) {
        [self.videoDecoder clean];
    }
    
    if (self.audioDecoder) {
        [self.audioDecoder clean];
    }
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self.operationQueue cancelAllOperations];
        [self.operationQueue waitUntilAllOperationsAreFinished];
        [self destroyFormatContext];
        [self closeOperation];
    });
    
}

- (void)destroyFormatContext {
    
    self.videoEnable = NO;
    self.audioEnable = NO;
    
    if (self.videoDecoder) {
        [self.videoDecoder destroyVideoTrack];
    }
    
    if (self.audioDecoder) {
        [self.audioDecoder destroyAudioTrack];
    }
    
    if (_format_context)
    {
        avformat_close_input(&_format_context);
        _format_context = NULL;
    }
    
}

- (void)closeOperation
{
    self.readPacketOperation = nil;
    self.openFileOperation = nil;
    self.decodeFrameOperation = nil;
    self.operationQueue = nil;
}

@end
