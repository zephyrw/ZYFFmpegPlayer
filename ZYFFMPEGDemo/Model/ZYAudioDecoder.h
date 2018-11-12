//
//  ZYAudioDecoder.h
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/11.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "avformat.h"

@class ZYAudioFrame;

@interface ZYAudioDecoder : NSObject

/**
 音频流的编号
 */
@property (assign, nonatomic) NSInteger streamIndex;

/**
 所有的packets的总大小
 */
@property (assign, nonatomic, readonly) int size;

/**
 音频总时长
 */
@property (assign, nonatomic) NSTimeInterval duration;

@property (assign, nonatomic, readonly) BOOL empty;

/**
 初始化音频解码器

 @param codecContext 解码上下文
 @param timeBase AVStream的时间基准
 @return 初始化之后的音频解码器
 */
+ (instancetype)audioDecoderWithCodecContext:(AVCodecContext *)codecContext timeBase:(NSTimeInterval)timeBase;

/**
 解码音频包

 @param packet 未解码的音频包
 @return 是否解码成功
 */
- (BOOL)decodePacket:(AVPacket)packet;

/**
 同步按顺序获取视频原始数据模型
 
 @return 音频原始数据模型
 */
- (ZYAudioFrame *)getFrameSync;

/**
 flush frame queue
 */
- (void)flush;

- (void)destroy;

/**
 关闭codec context
 */
- (void)destroyAudioTrack;

@end
