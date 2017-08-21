//
//  ZYAudioManager.h
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/14.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ZYAudioManager;

@protocol ZYAudioManagerDelegate <NSObject>
- (void)audioManager:(ZYAudioManager *)audioManager outputData:(float *)outputData numberOfFrames:(UInt32)numberOfFrames numberOfChannels:(UInt32)numberOfChannels;
@end

@interface ZYAudioManager : NSObject

@property (assign, nonatomic) Float64 samplingRate;
@property (assign, nonatomic) UInt32 numberOfChannels;
@property (assign, nonatomic, readonly) BOOL playing;
@property (weak, nonatomic) id<ZYAudioManagerDelegate> delegate;

/**
 单例
 */
+ (instancetype)shareInstance;

- (BOOL)registAudioSession;

- (void)resignAudioSession;

/**
 开始播放音频
 */
- (void)playWithDelegate:(id<ZYAudioManagerDelegate>)delegate;

/**
 暂停
 */
- (void)pause;

@end
