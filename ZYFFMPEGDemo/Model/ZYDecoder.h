//
//  ZYDecoder.h
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/10.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ZYVideoFrame, ZYAudioFrame, ZYDecoder;

@protocol ZYDecoderDelegate <NSObject>

@required
- (void)decoderWillOpenInputStream:(ZYDecoder *)decoder;      // open input stream
- (void)decoderDidPrepareToDecodeFrames:(ZYDecoder *)decoder;     // prepare decode frames
- (void)decoderDidEndOfFile:(ZYDecoder *)decoder;     // end of file
- (void)decoderDidPlaybackFinished:(ZYDecoder *)decoder;
- (void)decoder:(ZYDecoder *)decoder didError:(NSError *)error;       // error callback

// value change
- (void)decoder:(ZYDecoder *)decoder didChangeValueOfBuffering:(BOOL)buffering;
- (void)decoder:(ZYDecoder *)decoder didChangeValueOfBufferedDuration:(NSTimeInterval)bufferedDuration;
- (void)decoder:(ZYDecoder *)decoder didChangeValueOfProgress:(NSTimeInterval)progress;

@end

@interface ZYDecoder : NSObject

@property (weak, nonatomic) id<ZYDecoderDelegate> delegate;

/**
 是否正在缓冲
 */
@property (nonatomic, assign, readonly) BOOL buffering;

@property (atomic, assign, readonly) BOOL prepareToDecode;

/**
 是否是暂停状态
 */
@property (assign, nonatomic) BOOL paused;

@property (assign, nonatomic) BOOL playbackFinished;

/**
 总时长
 */
@property (assign, nonatomic) NSTimeInterval duration;

@property (assign, nonatomic) NSTimeInterval minBufferedDruation;

/**
 视频是否可用
 */
@property (assign, nonatomic, readonly) BOOL videoEnable;

@property (assign, nonatomic, readonly) NSTimeInterval progress;
@property (atomic, assign) NSTimeInterval videoFrameTimeClock;
@property (atomic, assign) NSTimeInterval videoFramePosition;
@property (atomic, assign) NSTimeInterval videoFrameDuration;

/**
 音频是否可用
 */
@property (assign, nonatomic, readonly) BOOL audioEnable;

@property (atomic, assign) NSTimeInterval audioFrameTimeClock;
@property (atomic, assign) NSTimeInterval audioFramePosition;
@property (atomic, assign) NSTimeInterval audioFrameDuration;


/**
 初始化解码器

 @param videoURL 视频URL
 @return 解码器
 */
+ (instancetype)decoderWithVideoURL:(NSURL *)videoURL;

/**
 异步按顺序获取视频原始数据模型
 
 @return 视频原始数据模型
 */
- (ZYVideoFrame *)getVideoFrameWithCurrentPosition:(NSTimeInterval)currentPosition currentDuration:(NSTimeInterval)currentDuration;

/**
 同步按顺序获取视频原始数据模型
 
 @return 音频原始数据模型
 */
- (ZYAudioFrame *)getAudioFrame;

- (void)seekToTime:(NSTimeInterval)time;
- (void)seekToTime:(NSTimeInterval)time completeHandler:(void (^)(BOOL finished))completeHandler;

/**
 暂停
 */
- (void)pause;

/**
 继续
 */
- (void)resume;

/**
 关闭视频文件并清空数据
 */
- (void)closeFile;

@end
