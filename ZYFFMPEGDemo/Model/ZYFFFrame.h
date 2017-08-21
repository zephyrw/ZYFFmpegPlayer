//
//  ZYFFFrame.h
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/11.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, ZYFrameType){
    ZYFrameTypeVideo,
    ZYFrameTypeAVYUVVideo,
    ZYFrameTypeCVYUVVideo,
    ZYFrameTypeAudio,
    ZYFrameTypeSubtitle,
    ZYFrameTypeArtwork,
};

@class ZYFFFrame;

@protocol ZYFFFrameDelegate <NSObject>

- (void)frameDidStartPlaying:(ZYFFFrame *)frame;
- (void)frameDidStopPlaying:(ZYFFFrame *)frame;
- (void)frameDidCancel:(ZYFFFrame *)frame;

@end

@interface ZYFFFrame : NSObject

/**
 是否正在播放
 */
@property (nonatomic, assign, readonly) BOOL playing;
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
 Frame的类型
 */
@property (assign, nonatomic, readonly) ZYFrameType type;

/**
 解压之前包的大小
 */
@property (nonatomic, assign) int packetSize;

/**
 代理
 */
@property (weak, nonatomic) id<ZYFFFrameDelegate> delegate;

- (void)startPlaying;
- (void)stopPlaying;
- (void)cancel;

@end
