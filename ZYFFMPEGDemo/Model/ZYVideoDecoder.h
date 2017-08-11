//
//  ZYVideoDecoder.h
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/11.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "avformat.h"

@class ZYVideoFrame;

@interface ZYVideoDecoder : NSObject

{
    @public
    AVCodecContext *_codec_context;
}

@property (assign, nonatomic) double timebase;
@property (assign, nonatomic) double fps;
@property (assign, nonatomic) CGSize videoPresentationSize;
@property (assign, nonatomic) CGFloat videoAspect;
@property (assign, nonatomic) NSInteger streamIndex;
@property (strong, nonatomic) NSCondition *packetCondition;
@property (strong, nonatomic) NSCondition *frameCondition;
@property (assign, nonatomic) int packetSize;
@property (assign, nonatomic) NSTimeInterval packetDuration;
@property (assign, nonatomic) NSTimeInterval bufferedDuration;
@property (strong, nonatomic) NSMutableArray <NSValue *> *packets;
@property (strong, nonatomic) NSMutableArray *frames;
@property (assign, nonatomic) int frameSize;
@property (assign, nonatomic) int framePacketSize;
@property (assign, nonatomic) NSTimeInterval frameDuration;
@property (strong, nonatomic) NSLock *framePoolLock;
@property (strong, nonatomic) NSMutableSet <ZYVideoFrame *> *unuseFrames;
@property (strong, nonatomic) NSMutableSet <ZYVideoFrame *> *usedFrames;

/**
 保存未解码的数据包

 @param packet 未解码的数据包
 */
- (void)savePacket:(AVPacket)packet;

/**
 异步按顺序获取视频原始数据模型
 
 @return 视频原始数据模型
 */
- (ZYVideoFrame *)getFrameAsync;

/**
 开始解码
 */
- (void)startDecodeThread;

/**
 清空解码器数据
 */
- (void)clean;

- (void)destroyVideoTrack;

@end
