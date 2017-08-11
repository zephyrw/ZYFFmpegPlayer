//
//  ZYFFFrame.h
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/11.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZYFFFrame : NSObject

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

- (void)startPlaying;
- (void)stopPlaying;
- (void)cancel;

@end
