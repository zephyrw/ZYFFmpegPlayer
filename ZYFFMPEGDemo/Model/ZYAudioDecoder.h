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

{
@public
    AVCodecContext *_codec_context;
}

@property (assign, nonatomic) double timebase;
@property (assign, nonatomic) double fps;
@property (assign, nonatomic) CGSize videoPresentationSize;
@property (assign, nonatomic) CGFloat videoAspect;
@property (assign, nonatomic) NSInteger streamIndex;

@property (strong, nonatomic) NSMutableArray <NSValue *> *packets;
@property (strong, nonatomic) NSCondition *packetCondition;
@property (strong, nonatomic) NSCondition *frameCondition;
@property (assign, nonatomic) NSTimeInterval packetDuration;
@property (assign, nonatomic) NSTimeInterval bufferedDuration;
@property (strong, nonatomic) NSMutableArray *frames;
@property (assign, nonatomic) int frameSize;
@property (assign, nonatomic) int framePacketSize;
@property (assign, nonatomic) NSTimeInterval frameDuration;
@property (strong, nonatomic) NSLock *framePoolLock;
@property (strong, nonatomic) NSMutableSet <ZYAudioFrame *> *unuseFrames;
@property (strong, nonatomic) NSMutableSet <ZYAudioFrame *> *usedFrames;

@end
