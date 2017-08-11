//
//  ZYVideoFrame.h
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/8.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "avformat.h"

typedef NS_ENUM(NSUInteger, SGFFVideoFrameRotateType) {
    SGFFVideoFrameRotateType0,
    SGFFVideoFrameRotateType90,
    SGFFVideoFrameRotateType180,
    SGFFVideoFrameRotateType270,
};

typedef NS_ENUM(int, SGYUVChannel) {
    SGYUVChannelLuma = 0,
    SGYUVChannelChromaB = 1,
    SGYUVChannelChromaR = 2,
    SGYUVChannelCount = 3,
};

@interface ZYVideoFrame : NSObject

{
@public
    UInt8 * channel_pixels[SGYUVChannelCount];
}

//@property (nonatomic, weak) id <SGFFFrameDelegate> delegate;
@property (nonatomic, assign, readonly) BOOL playing;

//@property (nonatomic, assign) SGFFFrameType type;

/**
 旋转角度
 */
@property (nonatomic, assign) SGFFVideoFrameRotateType rotateType;

/**
 当前视频桢的位置
 */
@property (nonatomic, assign) NSTimeInterval position;

/**
 当前视频frame的时长
 */
@property (nonatomic, assign) NSTimeInterval duration;

/**
 当前视频Frame的大小
 */
@property (nonatomic, assign, readonly) int size;

/**
 解压之前包的大小
 */
@property (nonatomic, assign) int packetSize;

/**
 宽度
 */
@property (nonatomic, assign, readonly) int width;

/**
 高度
 */
@property (nonatomic, assign, readonly) int height;

/**
 将视频Frame转化为数据用于渲染

 @param frame 原始视频Frame
 @param width 视频宽度
 @param height 视频高度
 */
- (void)setFrameData:(AVFrame *)frame width:(int)width height:(int)height;

- (void)startPlaying;
- (void)stopPlaying;
- (void)cancel;

@end
