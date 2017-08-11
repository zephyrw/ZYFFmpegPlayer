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

@property (assign, nonatomic) CGSize videoPresentationSize;
@property (assign, nonatomic) CGFloat videoAspect;
@property (assign, nonatomic) NSInteger streamIndex;
@property (assign, nonatomic, readonly) int packetSize;
@property (assign, nonatomic) NSInteger codecContextMaxDecodeFrameCount;

+ (instancetype)videoDecoderWithCodecContext:(AVCodecContext *)codecContext timeBase:(NSTimeInterval)timeBase fps:(NSTimeInterval)fps;

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
