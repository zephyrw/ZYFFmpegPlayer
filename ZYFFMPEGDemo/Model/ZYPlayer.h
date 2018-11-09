//
//  ZYPlayer.h
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/10.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZYConsts.h"

typedef NS_ENUM(NSInteger, ZYPLayerType) {
    ZYPLayerTypeAV = 0,
    ZYPLayerTypeFFmpeg,
    ZYPlayerTypeVR
};

typedef NS_ENUM(NSUInteger, ZYGravityMode) {
    ZYGravityModeResize,
    ZYGravityModeResizeAspect,
    ZYGravityModeResizeAspectFill,
};

typedef NS_ENUM(NSUInteger, ZYPlayerState) {
    ZYPlayerStateNone = 0,          // none
    ZYPlayerStateBuffering = 1,     // buffering
    ZYPlayerStateReadyToPlay = 2,   // ready to play
    ZYPlayerStatePlaying = 3,       // playing
    ZYPlayerStateSuspend = 4,       // pause
    ZYPlayerStateFinished = 5,      // finished
    ZYPlayerStateFailed = 6,        // failed
};

@class ZYDecoder;

@interface ZYPlayer : NSObject

/**
 播放器的View
 */
@property (strong, nonatomic) UIView *view;

/**
 隐藏动画
 */
@property (assign, nonatomic) BOOL viewAnimationHidden;

/**
 缩放模式
 */
@property (nonatomic, assign) ZYGravityMode viewGravityMode;       // default is ZYGravityModeResizeAspect;

/**
 播放状态
 */
@property (assign, nonatomic) ZYPlayerState state;

/**
 可播时长
 */
@property (nonatomic, assign, readonly) NSTimeInterval playableTime;
@property (assign, nonatomic) NSTimeInterval playableBufferInterval;

@property (assign, nonatomic, readonly) BOOL playing;

/**
 进度
 */
@property (assign, nonatomic, readonly) NSTimeInterval progress;

/**
 解码器
 */
@property (strong, nonatomic) ZYDecoder *decoder;

/**
 总时长
 */
@property (assign, nonatomic, readonly) NSTimeInterval duration;

/**
 初始化播放器
 */
+ (instancetype)player;

/**
 替换并播放视频

 @param videoURL 视频URL
 */
- (void)replaceVideoWithURL:(NSURL *)videoURL;

- (void)seekToTime:(NSTimeInterval)time;

/**
 开始播放
 */
- (void)play;

/**
 暂停
 */
- (void)pause;

/**
 清空
 */
- (void)clean;

@end
