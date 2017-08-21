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
#import "ZYAudioFrame.h"
#import "ZYVideoFrame.h"

@interface ZYDecoder()

{
    AVFormatContext *_format_context;
}

@property (copy, nonatomic) NSString *filePath;
@property (strong, nonatomic) NSDictionary *metadata;
@property (strong, nonatomic) NSMutableDictionary *formatContextOptions;
@property (strong, nonatomic) NSMutableDictionary *codecContextOptions;
@property (assign, nonatomic) BOOL reading;
@property (strong, nonatomic) ZYVideoDecoder *videoDecoder;
@property (strong, nonatomic) ZYAudioDecoder *audioDecoder;
@property (strong, nonatomic) NSOperationQueue *operationQueue;
@property (strong, nonatomic) NSInvocationOperation *openFileOperation;
@property (strong, nonatomic) NSInvocationOperation *readPacketOperation;
@property (strong, nonatomic) NSInvocationOperation *decodeFrameOperation;
@property (assign, nonatomic) NSTimeInterval bufferedDuration;
@property (assign, nonatomic) BOOL endOfFile;
@property (assign, nonatomic) BOOL seeking;
@property (assign, nonatomic) BOOL prepareToDecode;
@property (assign, nonatomic) BOOL closed;

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
    
    if ([self.delegate respondsToSelector:@selector(decoderWillOpenInputStream:)]) {
        [self.delegate decoderWillOpenInputStream:self];
    }
    
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
    
    if ([self.delegate respondsToSelector:@selector(decoderDidPrepareToDecodeFrames:)]) {
        [self.delegate decoderDidPrepareToDecodeFrames:self];
    }
    [self setupReadPacketOperation];
    
}

- (void)setupReadPacketOperation {
    
    if (!self.readPacketOperation || self.readPacketOperation.isFinished) {
        self.readPacketOperation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(readPacket) object:nil];
        self.readPacketOperation.queuePriority = NSOperationQueuePriorityVeryHigh;
        self.readPacketOperation.qualityOfService = NSQualityOfServiceUserInitiated;
        [self.readPacketOperation addDependency:self.openFileOperation];
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
        timeBase = av_q2d(stream->time_base);
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
        if (self.videoDecoder) {
            [self.videoDecoder clean];
            self.videoDecoder = nil;
        }
        self.videoDecoder = [ZYVideoDecoder videoDecoderWithCodecContext:codecContext timeBase:timeBase fps:fps];
        _videoEnable = YES;
        self.videoDecoder.streamIndex = streamIndex;
    } else {
        if (self.audioDecoder) {
            [self.audioDecoder clean];
            self.audioDecoder = nil;
        }
        self.audioDecoder = [ZYAudioDecoder audioDecoderWithCodecContext:codecContext timeBase:timeBase];
        _audioEnable = YES;
        self.audioDecoder.streamIndex = streamIndex;
    }
}

- (void)readPacket {
    
    AVPacket packet;
    
    while (YES) {
        
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
        if (result < 0) {
            NSLog(@"Finish to read frame!");
            self.endOfFile = YES;
            self.videoDecoder.endOfFile = YES;
            if ([self.delegate respondsToSelector:@selector(decoderDidEndOfFile:)]) {
                [self.delegate decoderDidEndOfFile:self];
            }
            break;
        }
        
        if (self.videoEnable && packet.stream_index == self.videoDecoder.streamIndex) {
            
            [self.videoDecoder savePacket:packet];
            [self updateBufferedDurationByVideo];
            
        }else if (self.audioEnable && packet.stream_index == self.audioDecoder.streamIndex) {
            
            if (![self.audioDecoder decodePacket:packet]) {
                NSLog(@"Failed to decode audio packet");
                continue;
            }
            [self updateBufferedDurationByAudio];
        }
    }
    
}

- (void)updateBufferedDurationByAudio
{
    if (self.audioEnable) {
        self.bufferedDuration = self.audioDecoder.duration;
    }
}

- (void)updateBufferedDurationByVideo
{
    if (!self.audioEnable) {
        self.bufferedDuration = self.videoDecoder.duration;
    }
}

- (NSTimeInterval)duration {
    if (!self->_format_context) return 0;
    int64_t duration = self->_format_context->duration;
    if (duration < 0) {
        return 0;
    }
    return (NSTimeInterval)duration / AV_TIME_BASE;
}

- (void)pause
{
    self.paused = YES;
}

- (void)resume
{
    self.paused = NO;
    if (self.playbackFinished) {
        [self seekToTime:0];
    }
}

- (void)seekToTime:(NSTimeInterval)time {
    
}

- (void)setBufferedDuration:(NSTimeInterval)bufferedDuration
{
    if (_bufferedDuration != bufferedDuration) {
        _bufferedDuration = bufferedDuration;
        if (_bufferedDuration <= 0.000001) {
            _bufferedDuration = 0;
        }
        if ([self.delegate respondsToSelector:@selector(decoder:didChangeValueOfBufferedDuration:)]) {
            [self.delegate decoder:self didChangeValueOfBufferedDuration:_bufferedDuration];
        }
        if (_bufferedDuration <= 0 && self.endOfFile) {
            self.playbackFinished = YES;
        }
        [self checkBufferingStatus];
    }
}

- (void)setBuffering:(BOOL)buffering {
    
    _buffering = buffering;
    if ([self.delegate respondsToSelector:@selector(decoder:didChangeValueOfBuffering:)]) {
        [self.delegate decoder:self didChangeValueOfBuffering:_buffering];
    }
    
}

- (void)checkBufferingStatus
{
    if (self.buffering) {
        if (self.bufferedDuration >= self.minBufferedDruation || self.endOfFile) {
            self.buffering = NO;
        }
    } else {
        if (self.bufferedDuration <= 0.2 && !self.endOfFile) {
            self.buffering = YES;
        }
    }
}

- (ZYVideoFrame *)getVideoFrameWithCurrentPosition:(NSTimeInterval)currentPosition currentDuration:(NSTimeInterval)currentDuration {
    if (self.closed) {
        return  nil;
    }
    if (self.seeking || self.buffering) {
        return  nil;
    }
    if (self.paused && self.videoFrameTimeClock > 0) {
        return nil;
    }
    if (self.audioEnable && self.audioFrameTimeClock < 0 && self.videoFrameTimeClock > 0) {
        return nil;
    }
    if (self.videoDecoder.empty) {
        return nil;
    }
    
    NSTimeInterval currentTime = [NSDate date].timeIntervalSince1970;
    ZYVideoFrame * videoFrame = nil;
    if (self.audioEnable)
    {
        if (self.videoFrameTimeClock < 0) {
            videoFrame = [self.videoDecoder getFrameAsync];
        } else {
            NSTimeInterval audioTimeClock = self.audioFrameTimeClock;
            NSTimeInterval audioTimeClockDelta = currentTime - audioTimeClock;
            NSTimeInterval audioPositionReal = self.audioFramePosition + audioTimeClockDelta;
            NSTimeInterval currentStop = currentPosition + currentDuration;
            if (currentStop <= audioPositionReal) {
                videoFrame = [self.videoDecoder getFrameAsyncPosistion:currentPosition];
            }
        }
    }
    else if (self.videoEnable)
    {
        if (self.videoFrameTimeClock < 0 || currentTime >= self.videoFrameTimeClock + self.videoFrameDuration) {
            videoFrame = [self.videoDecoder getFrameAsync];
        }
    }
    if (videoFrame) {
        self.videoFrameTimeClock = currentTime;
        self.videoFramePosition = videoFrame.position;
        self.videoFrameDuration = videoFrame.duration;
        [self updateProgressByVideo];
        if (self.endOfFile) {
            [self updateBufferedDurationByVideo];
        }
    }
    return videoFrame;
}

- (id)getAudioFrame {
    
    BOOL check = self.closed || self.seeking || self.buffering || self.paused || self.playbackFinished || !self.audioEnable;
    if (check) return nil;
    if (self.audioDecoder.empty) {
        [self updateBufferedDurationByAudio];
        return nil;
    }
    ZYAudioFrame * audioFrame = [self.audioDecoder getFrameSync];
    if (!audioFrame) return nil;
    self.audioFramePosition = audioFrame.position;
    self.audioFrameDuration = audioFrame.duration;
    
    if (self.endOfFile) {
        [self updateBufferedDurationByAudio];
    }
    [self updateProgressByAudio];
    self.audioFrameTimeClock = [NSDate date].timeIntervalSince1970;
    return audioFrame;
    
}

- (void)updateProgressByVideo;
{
    if (!self.audioEnable && self.videoEnable) {
        if (self.videoFramePosition > 0) {
            self.progress = self.videoFramePosition;
        } else {
            self.progress = 0;
        }
    }
}

- (void)updateProgressByAudio
{
    if (self.audioEnable) {
        if (self.audioFramePosition > 0) {
            self.progress = self.audioFramePosition;
        } else {
            self.progress = 0;
        }
    }
}

- (void)closeFile {
    
//    NSLog(@"Close decoder");
    if (self.videoDecoder) {
        [self.videoDecoder clean];
        self.videoDecoder = nil;
    }
    
    if (self.audioDecoder) {
        [self.audioDecoder clean];
        self.audioDecoder = nil;
    }
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self.operationQueue cancelAllOperations];
        [self.operationQueue waitUntilAllOperationsAreFinished];
        [self closePropertyValue];
        [self destroyFormatContext];
        [self closeOperation];
    });
    
}

- (void)setProgress:(NSTimeInterval)progress
{
    if (_progress != progress) {
        _progress = progress;
        if ([self.delegate respondsToSelector:@selector(decoder:didChangeValueOfProgress:)]) {
            [self.delegate decoder:self didChangeValueOfProgress:_progress];
        }
    }
}

- (void)closePropertyValue
{
    self.seeking = NO;
    self.buffering = NO;
    self.paused = NO;
    self.prepareToDecode = NO;
    self.endOfFile = NO;
    self.playbackFinished = NO;
    [self cleanAudioFrame];
    [self cleanVideoFrame];
    self.videoDecoder.paused = NO;
    self.videoDecoder.endOfFile = NO;
}

- (void)cleanAudioFrame
{
    self.audioFrameTimeClock = -1;
    self.audioFramePosition = -1;
    self.audioFrameDuration = -1;
}

- (void)cleanVideoFrame
{
    self.videoFrameTimeClock = -1;
    self.videoFramePosition = -1;
    self.videoFrameDuration = -1;
}

- (void)destroyFormatContext {
    
    _videoEnable = NO;
    _audioEnable = NO;
    
    if (self.videoDecoder) {
        [self.videoDecoder destroyVideoTrack];
    }
    
    if (self.audioDecoder) {
        [self.audioDecoder destroyAudioTrack];
    }
    
    if (_format_context)
    {
        avformat_close_input(&_format_context);
        avformat_free_context(_format_context);
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

- (void)dealloc
{
    [self closeFile];
    NSLog(@"%s", __func__);
}

@end
