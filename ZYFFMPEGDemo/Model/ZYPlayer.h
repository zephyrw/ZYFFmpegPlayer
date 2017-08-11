//
//  ZYPlayer.h
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/10.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import <UIKit/UIKit.h>

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

@class ZYDecoder;

@interface ZYPlayer : NSObject

/**
 播放器的View
 */
@property (strong, nonatomic) UIView *view;
@property (assign, nonatomic) BOOL viewAnimationHidden;

/**
 缩放模式
 */
@property (nonatomic, assign) ZYGravityMode viewGravityMode;       // default is ZYGravityModeResizeAspect;

/**
 解码器
 */
@property (strong, nonatomic) ZYDecoder *decoder;

/**
 初始化播放器
 */
+ (instancetype)player;

/**
 替换并播放视频

 @param videoURL 视频URL
 */
- (void)replaceVideoWithURL:(NSURL *)videoURL;

- (void)clean;

@end
