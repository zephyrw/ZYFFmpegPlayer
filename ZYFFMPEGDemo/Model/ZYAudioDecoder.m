//
//  ZYAudioDecoder.m
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/11.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import "ZYAudioDecoder.h"
#import "avformat.h"

@implementation ZYAudioDecoder

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.packets = [NSMutableArray array];
        self.frames = [NSMutableArray array];
        self.packetCondition = [NSCondition new];
        self.frameCondition = [NSCondition new];
        self.unuseFrames = [NSMutableSet setWithCapacity:60];
        self.usedFrames = [NSMutableSet setWithCapacity:60];
    }
    return self;
}

@end
