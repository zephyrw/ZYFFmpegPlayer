//
//  ZYFrameQueue.m
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/11.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import "ZYFrameQueue.h"
#import "ZYFFFrame.h"
#import "ZYVideoFrame.h"
#import "ZYAudioFrame.h"

@interface ZYFrameQueue () <ZYFFFrameDelegate>

@property (nonatomic, strong) NSCondition * condition;
@property (nonatomic, strong) NSMutableArray <__kindof ZYFFFrame *> * frames;

@property (nonatomic, assign) BOOL destoryToken;
// frame pool
@property (assign, nonatomic) ZYFrameType type;
@property (nonatomic, strong) NSLock * lock;
@property (nonatomic, strong) ZYFFFrame *playingFrame;
@property (nonatomic, strong) NSMutableSet <ZYFFFrame *> * unuseFrames;
@property (nonatomic, strong) NSMutableSet <ZYFFFrame *> * usedFrames;

@end

@implementation ZYFrameQueue

+ (instancetype)videoQueue {
    return [[self alloc] initWithType:ZYFrameTypeVideo capacity:60];
}

+ (instancetype)audioQueue {
    return [[self alloc] initWithType:ZYFrameTypeAudio capacity:500];
}

- (instancetype)initWithType:(ZYFrameType)type  capacity:(NSInteger)num
{
    if (self = [super init]) {
        self.type = type;
        self.frames = [NSMutableArray array];
        self.lock = [[NSLock alloc] init];
        self.unuseFrames = [NSMutableSet setWithCapacity:num];
        self.usedFrames = [NSMutableSet setWithCapacity:num];
        self.condition = [[NSCondition alloc] init];
        self.minFrameCountForGet = 1;
        self.ignoreMinFrameCountForGetLimit = NO;
    }
    return self;
}

- (void)putFrame:(__kindof ZYFFFrame *)frame
{
    if (!frame) return;
    [self.condition lock];
    if (self.destoryToken) {
        [self.condition unlock];
        return;
    }
    [self.frames addObject:frame];
    _duration += frame.duration;
    _size += frame.size;
    _packetSize += frame.packetSize;
    [self.condition signal];
    [self.condition unlock];
}

- (void)putSortFrame:(__kindof ZYFFFrame *)frame
{
    if (!frame) return;
    [self.condition lock];
    if (self.destoryToken) {
        [self.condition unlock];
        return;
    }
    BOOL added = NO;
    if (self.frames.count > 0) {
        for (int i = (int)self.frames.count - 1; i >= 0; i--) {
            ZYFFFrame * obj = [self.frames objectAtIndex:i];
            if (frame.position > obj.position) {
                [self.frames insertObject:frame atIndex:i + 1];
                added = YES;
                break;
            }
        }
    }
    if (!added) {
        [self.frames addObject:frame];
        added = YES;
    }
    _duration += frame.duration;
    _size += frame.size;
    _packetSize += frame.packetSize;
    [self.condition signal];
    [self.condition unlock];
}

- (__kindof ZYFFFrame *)getFrameSync
{
    [self.condition lock];
    while (self.frames.count < self.minFrameCountForGet && !(self.ignoreMinFrameCountForGetLimit && self.frames.firstObject)) {
        if (self.destoryToken) {
            [self.condition unlock];
            return nil;
        }
        [self.condition wait];
    }
    ZYFFFrame * frame = self.frames.firstObject;
    [self.frames removeObjectAtIndex:0];
    _duration -= frame.duration;
    if (_duration < 0 || self.count <= 0) {
        _duration = 0;
    }
    _size -= frame.size;
    if (self.size <= 0 || self.count <= 0) {
        _size = 0;
    }
    _packetSize -= frame.packetSize;
    if (_packetSize <= 0 || self.count <= 0) {
        _packetSize = 0;
    }
    [self.condition unlock];
    return frame;
}

- (__kindof ZYFFFrame *)getFrameAsync
{
    [self.condition lock];
    if (self.destoryToken || self.frames.count <= 0) {
        [self.condition unlock];
        return nil;
    }
    if (!self.ignoreMinFrameCountForGetLimit && self.frames.count < self.minFrameCountForGet) {
        [self.condition unlock];
        return nil;
    }
    ZYFFFrame * frame = self.frames.firstObject;
    [self.frames removeObjectAtIndex:0];
    _duration -= frame.duration;
    if (self.duration < 0 || self.count <= 0) {
        _duration = 0;
    }
    _size -= frame.size;
    if (self.size <= 0 || self.count <= 0) {
        _size = 0;
    }
    _packetSize -= frame.packetSize;
    if (self.packetSize <= 0 || self.count <= 0) {
        _packetSize = 0;
    }
    [self.condition unlock];
    return frame;
}

- (__kindof ZYFFFrame *)getFrameAsyncPosistion:(NSTimeInterval)position discardFrames:(NSMutableArray <__kindof ZYFFFrame *> **)discardFrames
{
    [self.condition lock];
    if (self.destoryToken || self.frames.count <= 0) {
        [self.condition unlock];
        return nil;
    }
    if (!self.ignoreMinFrameCountForGetLimit && self.frames.count < self.minFrameCountForGet) {
        [self.condition unlock];
        return nil;
    }
    ZYFFFrame * frame = nil;
    NSMutableArray * temp = [NSMutableArray array];
    for (ZYFFFrame * obj in self.frames) {
        if (obj.position + obj.duration < position) {
            [temp addObject:obj];
            _duration -= obj.duration;
            _size -= obj.size;
            _packetSize -= obj.packetSize;
        } else {
            break;
        }
    }
    if (temp.count > 0) {
        frame = temp.lastObject;
        [self.frames removeObjectsInArray:temp];
        [temp removeObject:frame];
        if (temp.count > 0) {
            * discardFrames = temp;
        }
    } else {
        frame = self.frames.firstObject;
        [self.frames removeObject:frame];
        _duration -= frame.duration;
        _size -= frame.size;
        _packetSize -= frame.packetSize;
    }
    if (self.duration < 0 || self.count <= 0) {
        _duration = 0;
    }
    if (self.size <= 0 || self.count <= 0) {
        _size = 0;
    }
    if (self.packetSize <= 0 || self.count <= 0) {
        _packetSize = 0;
    }
    [self.condition unlock];
    return frame;
}

- (NSTimeInterval)getFirstFramePositionAsync
{
    [self.condition lock];
    if (self.destoryToken || self.frames.count <= 0) {
        [self.condition unlock];
        return -1;
    }
    if (!self.ignoreMinFrameCountForGetLimit && self.frames.count < self.minFrameCountForGet) {
        [self.condition unlock];
        return -1;
    }
    NSTimeInterval time = self.frames.firstObject.position;
    [self.condition unlock];
    return time;
}

- (NSMutableArray <__kindof ZYFFFrame *> *)discardFrameBeforPosition:(NSTimeInterval)position
{
    [self.condition lock];
    if (self.destoryToken || self.frames.count <= 0) {
        [self.condition unlock];
        return nil;
    }
    if (!self.ignoreMinFrameCountForGetLimit && self.frames.count < self.minFrameCountForGet) {
        [self.condition unlock];
        return nil;
    }
    NSMutableArray * temp = [NSMutableArray array];
    for (ZYFFFrame * obj in self.frames) {
        if (obj.position + obj.duration < position) {
            [temp addObject:obj];
            _duration -= obj.duration;
            _size -= obj.size;
            _packetSize -= obj.packetSize;
        } else {
            break;
        }
    }
    if (temp.count > 0) {
        [self.frames removeObjectsInArray:temp];
    }
    if (self.duration < 0 || self.count <= 0) {
        _duration = 0;
    }
    if (self.size <= 0 || self.count <= 0) {
        _size = 0;
    }
    if (self.packetSize <= 0 || self.count <= 0) {
        _packetSize = 0;
    }
    [self.condition unlock];
    if (temp.count > 0) {
        return temp;
    } else {
        return nil;
    }
}

#pragma mark - frame pool

- (__kindof ZYFFFrame *)getUnuseFrame {
    
    [self.lock lock];
    ZYFFFrame *frame;
    if (self.unuseFrames.count > 0) {
        frame = [self.unuseFrames anyObject];
        [self.unuseFrames removeObject:frame];
        [self.usedFrames addObject:frame];
        
    } else {
        if (self.type == ZYFrameTypeVideo) {
            frame = [ZYVideoFrame new];
        } else if (self.type == ZYFrameTypeAudio){
            frame = [ZYAudioFrame new];
        }
        frame.delegate = self;
        [self.usedFrames addObject:frame];
    }
    [self.lock unlock];
    return frame;
    
}

- (void)setFrameStartDrawing:(ZYFFFrame *)frame
{
    if (!frame) return;
    if (frame.type != self.type) return;
    [self.lock lock];
    if (self.playingFrame) {
        [self.unuseFrames addObject:self.playingFrame];
    }
    self.playingFrame = frame;
    [self.usedFrames removeObject:self.playingFrame];
    [self.lock unlock];
}

- (void)setFrameStopDrawing:(ZYFFFrame *)frame
{
    if (!frame) return;
    if (frame.type != self.type) return;
    [self.lock lock];
    if (self.playingFrame == frame) {
        [self.unuseFrames addObject:self.playingFrame];
        self.playingFrame = nil;
    }
    [self.lock unlock];
}

- (void)setFrameUnuse:(ZYFFFrame *)frame
{
    if (!frame) return;
    if (frame.type != self.type) return;
    [self.lock lock];
    [self.unuseFrames addObject:frame];
    [self.usedFrames removeObject:frame];
    [self.lock unlock];
}

- (NSUInteger)framePoolCount
{
    return [self unuseCount] + [self usedCount] + (self.playingFrame ? 1 : 0);
}

- (NSUInteger)unuseCount
{
    return self.unuseFrames.count;
}

- (NSUInteger)usedCount
{
    return self.usedFrames.count;
}

- (void)flush
{
    [self.condition lock];
    [self.frames removeAllObjects];
    _duration = 0;
    _size = 0;
    _packetSize = 0;
    self.ignoreMinFrameCountForGetLimit = NO;
    [self.condition unlock];
}

- (void)flushFramePool {
    
    [self.lock lock];
    [self.usedFrames enumerateObjectsUsingBlock:^(ZYFFFrame * _Nonnull obj, BOOL * _Nonnull stop) {
        [self.unuseFrames addObject:obj];
    }];
    [self.usedFrames removeAllObjects];
    [self.lock unlock];
    
}

- (void)destroy
{
    [self flush];
    [self.condition lock];
    self.destoryToken = YES;
    [self.condition broadcast];
    [self.condition unlock];
}

- (NSUInteger)count
{
    return self.frames.count;
}

+ (NSTimeInterval)maxVideoDuration
{
    return 1.0;
}

+ (NSTimeInterval)sleepTimeIntervalForFull
{
    return [self maxVideoDuration] / 2.0f;
}

+ (NSTimeInterval)sleepTimeIntervalForFullAndPaused
{
    return [self maxVideoDuration] / 1.1f;
}

#pragma mark - ZYFFFrameDelegate

- (void)frameDidStartPlaying:(ZYFFFrame *)frame
{
    [self setFrameStartDrawing:frame];
}

- (void)frameDidStopPlaying:(ZYFFFrame *)frame
{
    [self setFrameStopDrawing:frame];
}

- (void)frameDidCancel:(ZYFFFrame *)frame
{
    [self setFrameUnuse:frame];
}

- (void)dealloc {
    NSLog(@"%s", __func__);
}

@end
