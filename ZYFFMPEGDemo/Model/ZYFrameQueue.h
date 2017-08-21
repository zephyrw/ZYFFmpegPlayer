//
//  ZYFrameQueue.h
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/11.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZYFFFrame.h"

@interface ZYFrameQueue : NSObject

@property (nonatomic, assign, readonly) int size;
@property (nonatomic, assign, readonly) int packetSize;
@property (nonatomic, assign, readonly) NSUInteger count;
@property (atomic, assign, readonly) NSTimeInterval duration;
@property (nonatomic, assign, readonly) NSUInteger framePoolCount;

@property (nonatomic, assign) NSUInteger minFrameCountForGet;    // default is 1.
@property (nonatomic, assign) BOOL ignoreMinFrameCountForGetLimit;


+ (instancetype)videoQueue;
+ (instancetype)audioQueue;

+ (NSTimeInterval)maxVideoDuration;

+ (NSTimeInterval)sleepTimeIntervalForFull;
+ (NSTimeInterval)sleepTimeIntervalForFullAndPaused;

- (void)putFrame:(__kindof ZYFFFrame *)frame;
- (void)putSortFrame:(__kindof ZYFFFrame *)frame;
- (__kindof ZYFFFrame *)getFrameSync;
- (__kindof ZYFFFrame *)getFrameAsync;
- (__kindof ZYFFFrame *)getFrameAsyncPosistion:(NSTimeInterval)position discardFrames:(NSMutableArray <__kindof ZYFFFrame *> **)discardFrames;
- (NSTimeInterval)getFirstFramePositionAsync;
- (NSMutableArray <__kindof ZYFFFrame *> *)discardFrameBeforPosition:(NSTimeInterval)position;

- (__kindof ZYFFFrame *)getUnuseFrame;

- (NSUInteger)unuseCount;
- (NSUInteger)usedCount;

- (void)flush;
- (void)flushFramePool;
- (void)destroy;

@end
