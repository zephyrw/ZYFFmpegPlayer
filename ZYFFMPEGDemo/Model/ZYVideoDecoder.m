//
//  ZYVideoDecoder.m
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/11.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import "ZYVideoDecoder.h"
#import "ZYVideoFrame.h"
#import "avformat.h"
#import "ZYFrameQueue.h"
#import "ZYPacketQueue.h"

@interface ZYVideoDecoder ()
{
    AVFrame	*_temp_frame;
    AVCodecContext *_codec_context;
}

@property (strong, nonatomic) ZYFrameQueue *frameQueue;
@property (strong, nonatomic) ZYPacketQueue *packetQueue;
@property (assign, nonatomic) double timebase;
@property (assign, nonatomic) double fps;

@end

@implementation ZYVideoDecoder

static AVPacket flushPacket;

+ (instancetype)videoDecoderWithCodecContext:(AVCodecContext *)codecContext timeBase:(NSTimeInterval)timeBase fps:(NSTimeInterval)fps {
    
    return [[self alloc] initWithCodecContext:codecContext timeBase:timeBase fps:fps];
    
}

- (instancetype)initWithCodecContext:(AVCodecContext *)codecContext timeBase:(NSTimeInterval)timeBase fps:(NSTimeInterval)fps
{
    self = [super init];
    if (self) {
        _temp_frame = av_frame_alloc();
        self.frameQueue = [ZYFrameQueue videoQueue];
        self.packetQueue = [ZYPacketQueue packetQueueWithTimebase:timeBase];
        self.timebase = timeBase;
        self.fps = fps;
        self->_codec_context = codecContext;
        self.codecContextMaxDecodeFrameCount = 3;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            av_init_packet(&flushPacket);
            flushPacket.data = (uint8_t *)&flushPacket;
            flushPacket.duration = 0;
        });
    }
    return self;
}

- (void)startDecodeThread {
    
    while (YES) {
        
        if (self.endOfFile && self.packetQueue.count <= 0) {
            NSLog(@"Decode video finished!");
            break;
        }
        
        if (self.paused) {
            NSLog(@"decode video thread pause sleep");
            [NSThread sleepForTimeInterval:0.03];
            continue;
        }
        
        if (self.frameQueue.count >= self.codecContextMaxDecodeFrameCount) {
//            NSLog(@"decode video thread sleep");
            [NSThread sleepForTimeInterval:0.03];
            continue;
        }
        
        AVPacket packet = [self.packetQueue getPacketAsync];
        
        if (packet.data == flushPacket.data) {
            NSLog(@"video codec flush");
            avcodec_flush_buffers(_codec_context);
            [self.frameQueue flush];
            continue;
        }
        
        if (packet.stream_index < 0 || packet.data == NULL) {
            continue;
        }
        
        int result = avcodec_send_packet(_codec_context, &packet);
        if (result < 0) {
            if (result != AVERROR(EAGAIN) && result != AVERROR_EOF) {
                NSLog(@"Finish to send packet!");
                break;
            }
        } else {
            while (result >= 0) {
                result = avcodec_receive_frame(_codec_context, _temp_frame);
                if (result < 0) {
                    if (result != AVERROR(EAGAIN) && result != AVERROR_EOF) {
                        NSLog(@"Failed to receive frame: %d", result);
                    }
                } else {
                    ZYVideoFrame *videoFrame = [self videoFrameFromTempFrame:packet.size];
                    if (videoFrame) {
                        [self.frameQueue putSortFrame:videoFrame];
                    }
                }
            }
        }
        av_packet_unref(&packet);
    }
    
}

- (void)savePacket:(AVPacket)packet {
    
    NSTimeInterval duration = 0;
    if (packet.duration <= 0 && packet.size > 0 && packet.data != flushPacket.data) {
        duration = 1.0 / self.fps;
    }
    [self.packetQueue putPacket:packet duration:duration];
    
}

- (ZYVideoFrame *)getFrameAsync {
    
    return [self.frameQueue getFrameAsync];
    
}

- (ZYVideoFrame *)getFrameAsyncPosistion:(NSTimeInterval)position
{
    NSMutableArray <ZYFFFrame *> * discardFrames = nil;
    ZYVideoFrame * videoFrame = [self.frameQueue getFrameAsyncPosistion:position discardFrames:&discardFrames];
    for (ZYVideoFrame * obj in discardFrames) {
        [obj cancel];
    }
    return videoFrame;
}

- (int)packetSize {
    return self.packetQueue.size + self.frameQueue.packetSize;
}

- (NSTimeInterval)duration {
    return self.packetQueue.duration + self.frameQueue.duration;
}

- (BOOL)empty {
    return self.frameQueue.count <= 0 && self.packetQueue.count <= 0;
}

- (void)clean {
//    NSLog(@"Release video decoder");
    [self.frameQueue destroy];
    [self.packetQueue destroy];
    [self.frameQueue flushFramePool];
}

- (void)destroyVideoTrack
{
    if (_codec_context)
    {
        avcodec_close(_codec_context);
        avcodec_free_context(&_codec_context);
        _codec_context = NULL;
    }
}

- (ZYVideoFrame *)videoFrameFromTempFrame:(int)packetSize {
    
    if (!_temp_frame->data[0] || !_temp_frame->data[1] || !_temp_frame->data[2]) return nil;
    ZYVideoFrame * videoFrame = [self.frameQueue getUnuseFrame];
    
    [videoFrame setFrameData:_temp_frame width:_codec_context->width height:_codec_context->height];
    videoFrame.position = av_frame_get_best_effort_timestamp(_temp_frame) * self.timebase;
    videoFrame.packetSize = packetSize;
    
    const int64_t frame_duration = av_frame_get_pkt_duration(_temp_frame);
    if (frame_duration) {
        videoFrame.duration = frame_duration * self.timebase;
        videoFrame.duration += _temp_frame->repeat_pict * self.timebase * 0.5;
    } else {
        videoFrame.duration = 1.0 / self.fps;
    }
    return videoFrame;
}

- (void)dealloc
{
    if (_temp_frame) {
        av_frame_free(&_temp_frame);
        _temp_frame = NULL;
    }
    NSLog(@"%s", __func__);
}

@end
