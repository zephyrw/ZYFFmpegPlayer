//
//  ZYDecoder.h
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/10.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ZYVideoFrame, ZYDecoder;

@protocol ZYDecoderDelegate <NSObject>

@required
- (void)decoderDidPrepareToDecodeFrames;

@end

@interface ZYDecoder : NSObject

@property (weak, nonatomic) id<ZYDecoderDelegate> delegate;

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
- (ZYVideoFrame *)getFrameAsync;

/**
 关闭视频文件并清空数据
 */
- (void)closeFile;

@end
