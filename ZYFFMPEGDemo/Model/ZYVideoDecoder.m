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

@interface ZYVideoDecoder ()
{
    AVFrame	*_temp_frame;
}

@end

@implementation ZYVideoDecoder

static AVPacket flushPacket;

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.packets = [NSMutableArray array];
        self.frames = [NSMutableArray array];
        self.packetCondition = [NSCondition new];
        self.frameCondition = [NSCondition new];
        self.unuseFrames = [NSMutableSet setWithCapacity:60];
        self.usedFrames = [NSMutableSet setWithCapacity:60];
        _temp_frame = av_frame_alloc();
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            av_init_packet(&flushPacket);
            flushPacket.data = (uint8_t *)&flushPacket;
            flushPacket.duration = 0;
        });
    }
    return self;
}

- (void)savePacket:(AVPacket)packet {
    
    [self.packetCondition lock];
    NSValue *value = [NSValue value:&packet withObjCType:@encode(AVPacket)];
    [self.packets addObject:value];
    self.packetSize += packet.size;
    NSTimeInterval duration = 1.0 / self.fps;
    if (packet.duration <= 0 && packet.size > 0 && &packet != &flushPacket && duration > 0) {
        self.packetDuration += duration;
    } else if (packet.duration > 0) {
        self.packetDuration += packet.duration * self.timebase;
    }
    [self.packetCondition signal];
    [self.packetCondition unlock];
    
    self.bufferedDuration = self.packetDuration + self.frameDuration;
    
}

- (void)startDecodeThread {
    
    while (YES) {
        if (self.frames.count >= 3) {
            //            NSLog(@"decode video thread sleep");
            [NSThread sleepForTimeInterval:0.03];
            continue;
        }
        
        AVPacket packet = [self getPacketAsync];
        
        if (packet.data == flushPacket.data) {
            NSLog(@"video codec flush");
            avcodec_flush_buffers(_codec_context);
            [self flushFrameQueue];
            continue;
        }
        
        if (packet.stream_index < 0 || packet.data == NULL) {
            continue;
        }
        
        int result = avcodec_send_packet(_codec_context, &packet);
        if (result < 0) {
            NSLog(@"Failed to send packet: %d", result);
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
                        [self putSortFrame:videoFrame];
                    }
                }
            }
        }
        av_packet_unref(&packet);
    }
    
}

- (void)clean {
    
    [self destroyFrameQueue];
    [self destroyPacketQueue];
    [self flushFramePool];
    
}

- (void)destroyFrameQueue {
    
    [self.frameCondition lock];
    [self.frames removeAllObjects];
    self.frameDuration = 0;
    self.frameSize = 0;
    self.packetSize = 0;
    [self.frameCondition unlock];
}

- (void)destroyPacketQueue {
    
    [self.packetCondition lock];
    for (NSValue * value in self.packets) {
        AVPacket packet;
        [value getValue:&packet];
        av_packet_unref(&packet);
    }
    [self.packets removeAllObjects];
    self.packetSize = 0;
    self.packetDuration = 0;
    [self.packetCondition unlock];
}

- (void)flushFramePool {
    
    [self.framePoolLock lock];
    [self.usedFrames enumerateObjectsUsingBlock:^(ZYVideoFrame * _Nonnull obj, BOOL * _Nonnull stop) {
        [self.unuseFrames addObject:obj];
    }];
    [self.usedFrames removeAllObjects];
    [self.framePoolLock unlock];
}

- (void)destroyVideoTrack
{
    if (_codec_context)
    {
        avcodec_close(_codec_context);
        _codec_context = NULL;
    }
}

- (ZYVideoFrame *)videoFrameFromTempFrame:(int)packetSize {
    
    if (!_temp_frame->data[0] || !_temp_frame->data[1] || !_temp_frame->data[2]) return nil;
    ZYVideoFrame * videoFrame = [self getUnuseFrame];
    
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

- (ZYVideoFrame *)getUnuseFrame
{
    [self.framePoolLock lock];
    ZYVideoFrame * frame;
    if (self.unuseFrames.count > 0) {
        frame = [self.unuseFrames anyObject];
        [self.unuseFrames removeObject:frame];
        [self.usedFrames addObject:frame];
        
    } else {
        frame = [[ZYVideoFrame alloc] init];
        //        frame.delegate = self;
        [self.usedFrames  addObject:frame];
    }
    [self.framePoolLock unlock];
    return frame;
}

- (void)putSortFrame:(ZYVideoFrame *)frame
{
    if (!frame) return;
    [self.frameCondition lock];
    BOOL added = NO;
    if (self.frames.count > 0) {
        for (int i = (int)self.frames.count - 1; i >= 0; i--) {
            ZYVideoFrame * obj = [self.frames objectAtIndex:i];
            if (frame.position > obj.position) {
                [self.frames insertObject:frame atIndex:i + 1];
                added = YES;
                break;
            }
        }
    }
    if (!added) {
        [self.frames addObject:frame];
        added = YES;
    }
    self.frameDuration += frame.duration;
    self.frameSize += frame.size;
    self.framePacketSize += frame.packetSize;
    [self.frameCondition signal];
    [self.frameCondition unlock];
}

- (AVPacket)getPacketAsync
{
    [self.packetCondition lock];
    AVPacket packet;
    packet.stream_index = -2;
    while (!self.packets.firstObject) {
        [self.packetCondition wait];
    }
    [self.packets.firstObject getValue:&packet];
    [self.packets removeObjectAtIndex:0];
    self.packetSize -= packet.size;
    if (self.packetSize < 0 || self.packets.count <= 0) {
        self.packetSize = 0;
    }
    self.packetDuration -= packet.duration * self.timebase;
    if (self.packetDuration < 0 || self.packets.count <= 0) {
        self.packetDuration = 0;
    }
    [self.packetCondition unlock];
    return packet;
}

- (ZYVideoFrame *)getFrameAsync
{
    [self.frameCondition lock];
    if (self.frames.count <= 0) {
        [self.frameCondition unlock];
        return nil;
    }
    
    ZYVideoFrame * frame = self.frames.firstObject;
    [self.frames removeObjectAtIndex:0];
    self.frameDuration -= frame.duration;
    if (self.frameDuration < 0 || self.frames.count <= 0) {
        self.frameDuration = 0;
    }
    self.frameSize -= frame.size;
    if (self.frameSize <= 0 || self.frames.count <= 0) {
        self.frameSize = 0;
    }
    self.packetSize -= frame.packetSize;
    if (self.packetSize <= 0 || self.frames.count <= 0) {
        self.packetSize = 0;
    }
    [self.frameCondition unlock];
    return frame;
}

- (void)flushFrameQueue {
    
    [self.frameCondition lock];
    [self.frames removeAllObjects];
    self.frameDuration = 0;
    self.frameSize = 0;
    self.packetSize = 0;
    [self.frameCondition unlock];
    
}

@end
