//
//  ZYPacketQueue.h
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/11.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "avformat.h"

@interface ZYPacketQueue : NSObject

+ (instancetype)packetQueueWithTimebase:(NSTimeInterval)timebase;

@property (nonatomic, assign, readonly) NSUInteger count;
@property (nonatomic, assign, readonly) int size;
@property (atomic, assign, readonly) NSTimeInterval duration;
@property (nonatomic, assign, readonly) NSTimeInterval timebase;

- (void)putPacket:(AVPacket)packet duration:(NSTimeInterval)duration;
- (AVPacket)getPacketSync;
- (AVPacket)getPacketAsync;

- (void)flush;
- (void)destroy;

@end
