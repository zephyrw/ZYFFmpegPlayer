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

/**
 视频显示大小
 */
@property (assign, nonatomic) CGSize videoPresentationSize;

/**
 视频比例
 */
@property (assign, nonatomic) CGFloat videoAspect;

/**
 视频流的编号
 */
@property (assign, nonatomic) NSInteger streamIndex;

/**
 AVPacket的总大小
 */
@property (assign, nonatomic, readonly) int packetSize;

/**
 视频总时长
 */
@property (assign, nonatomic) NSTimeInterval duration;

/**
 packet是否读取完成
 */
@property (assign, nonatomic) BOOL endOfFile;

/**
 是否暂停
 */
@property (nonatomic, assign) BOOL paused;

/**
 是否是空的
 */
@property (assign, nonatomic, readonly) BOOL empty;

/**
 最多多少个frame同时解码
 */
@property (assign, nonatomic) NSInteger codecContextMaxDecodeFrameCount;

/**
 初始化视频解码器

 @param codecContext 编解码上下文
 @param timeBase AVStream的时间基准
 @param fps 帧频
 @return 视频解码器
 */
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
 异步根据位置按顺序获取视频原始数据模型
 
 @return 视频原始数据模型
 */
- (ZYVideoFrame *)getFrameAsyncPosistion:(NSTimeInterval)position;

/**
 开始解码
 */
- (void)startDecodeThread;

/**
 清空解码器数据
 */
- (void)destroy;

- (void)flush;

/**
 关闭解码器上下文
 */
- (void)destroyVideoTrack;

@end
