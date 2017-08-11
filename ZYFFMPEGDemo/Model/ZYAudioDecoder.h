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

@property (assign, nonatomic) NSInteger streamIndex;
@property (assign, nonatomic, readonly) int size;

+ (instancetype)audioDecoderWithCodecContext:(AVCodecContext *)codecContext timeBase:(NSTimeInterval)timeBase;

- (BOOL)decodePacket:(AVPacket)packet;
- (void)clean;
- (void)destroyAudioTrack;

@end
