//
//  ZYPlayer.m
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/10.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import "ZYPlayer.h"
#import "ZYDisplayView.h"
#import "ZYDecoder.h"
#import "ZYAudioManager.h"
#import "ZYAudioFrame.h"

@interface ZYPlayer () <ZYDecoderDelegate, ZYAudioManagerDelegate>

@property (strong, nonatomic) ZYDisplayView *displayView;
@property (strong, nonatomic) ZYAudioManager *audioManager;
@property (strong, nonatomic) ZYAudioFrame *currentAudioFrame;
@property (strong, nonatomic) NSLock *stateLock;
@property (assign, nonatomic) BOOL prepareToken;

@end

@implementation ZYPlayer

+ (instancetype)player {
    return [[self alloc] init];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewGravityMode = ZYGravityModeResizeAspect;
        self.playableBufferInterval = 2;
        [[ZYAudioManager shareInstance] registAudioSession];
    }
    return self;
}

- (void)replaceVideoWithURL:(NSURL *)videoURL {
    
    [self clean];
    self.decoder = [ZYDecoder decoderWithVideoURL:videoURL];
    self.decoder.delegate = self;
    
}

- (void)play {
    
    _playing = YES;
    [self.decoder resume];
    
    switch (self.state) {
        case ZYPlayerStateFinished:
            [self seekToTime:0];
            break;
        case ZYPlayerStateNone:
        case ZYPlayerStateFailed:
        case ZYPlayerStateBuffering:
            self.state = ZYPlayerStateBuffering;
            break;
        case ZYPlayerStateSuspend:
            if (self.decoder.buffering) {
                self.state = ZYPlayerStateBuffering;
            } else {
                self.state = ZYPlayerStatePlaying;
            }
            break;
        case ZYPlayerStateReadyToPlay:
        case ZYPlayerStatePlaying:
            self.state = ZYPlayerStatePlaying;
            break;
    }
}

- (void)pause
{
    _playing = NO;
    [self.decoder pause];
    
    switch (self.state) {
        case ZYPlayerStateNone:
        case ZYPlayerStateSuspend:
            break;
        case ZYPlayerStateFailed:
        case ZYPlayerStateReadyToPlay:
        case ZYPlayerStateFinished:
        case ZYPlayerStatePlaying:
        case ZYPlayerStateBuffering:
        {
            self.state = ZYPlayerStateSuspend;
        }
            break;
    }
}

- (void)setState:(ZYPlayerState)state {
    
    [self.stateLock lock];
    if (_state != state) {
        ZYPlayerState temp = _state;
        _state = state;
        if (_state == ZYPlayerStatePlaying) {
            [[ZYAudioManager shareInstance] playWithDelegate:self];
        } else {
            [self.audioManager pause];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationPlayerStateChangeKey object:self userInfo:@{kPreviousKey: @(temp),kCurrentKey: @(_state)}];
    }
    [self.stateLock unlock];
    
}

- (void)seekToTime:(NSTimeInterval)time
{
    [self seekToTime:time completeHandler:nil];
}

- (void)seekToTime:(NSTimeInterval)time completeHandler:(void (^)(BOOL finished))completeHandler
{
    if (!self.decoder.prepareToDecode) {
        if (completeHandler) {
            completeHandler(NO);
        }
        return;
    }
    [self.decoder seekToTime:time completeHandler:completeHandler];
}

- (void)cleanFrame {
    [self.currentAudioFrame stopPlaying];
    self.currentAudioFrame = nil;
}

- (void)cleanPlayer {
    
    _playing = NO;
    self.state = ZYPlayerStateNone;
    self.progress = 0;
    _playableTime = 0;
    self.prepareToken = NO;
    [self.displayView rendererWithTypeEmpty];
    
}

- (UIView *)view
{
    return self.displayView;
}

- (NSTimeInterval)duration
{
    return self.decoder.duration;
}

- (void)setProgress:(NSTimeInterval)progress
{
    if (_progress != progress) {
        _progress = progress;
        NSTimeInterval duration = self.duration;
        double percent = [self percentForTime:_progress duration:duration];
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationPlayerProgressChangeKey object:self userInfo:@{kPercentKey:@(percent), kCurrentKey: @(progress), kTotoalKey: @(duration)}];
    }
}

- (void)setPlayableBufferInterval:(NSTimeInterval)playableBufferInterval {
    _playableBufferInterval = playableBufferInterval;
    self.decoder.minBufferedDruation = playableBufferInterval;
}

- (double)percentForTime:(NSTimeInterval)time duration:(NSTimeInterval)duration
{
    double percent = 0;
    if (time > 0) {
        if (duration <= 0) {
            percent = 1;
        } else {
            percent = time / duration;
        }
    }
    return percent;
}


- (void)dealloc {
    NSLog(@"%s", __func__);
    [self clean];
    [[ZYAudioManager shareInstance] resignAudioSession];
}

- (void)clean {
    
    [self cleanDecoder];
    [self cleanFrame];
    [self cleanPlayer];
    [self.view.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj removeFromSuperview];
    }];
    
}

- (void)cleanDecoder {
    
    if (self.decoder) {
        [self.decoder closeFile];
        self.decoder = nil;
    }
    
}

- (ZYDisplayView *)displayView {
    
    if (!_displayView) {
        _displayView = [ZYDisplayView displayViewWithAbstractPlayer:self];
    }
    return _displayView;
    
}

- (void)setViewGravityMode:(ZYGravityMode)viewGravityMode {
    
    _viewGravityMode = viewGravityMode;
    [self.displayView reloadGravityMode];
    
}

#pragma ZYDecoderDelegate

- (void)decoderWillOpenInputStream:(ZYDecoder *)decoder
{
    self.state = ZYPlayerStateBuffering;
}

- (void)decoderDidPrepareToDecodeFrames:(ZYDecoder *)decoder
{
    if (self.decoder.videoEnable) {
        [self.displayView rendererWithTypeOpenGL];
    }
}

- (void)decoderDidEndOfFile:(ZYDecoder *)decoder
{
    _playableTime = self.duration;
}

- (void)decoderDidPlaybackFinished:(ZYDecoder *)decoder
{
    self.state = ZYPlayerStateFinished;
}

- (void)decoder:(ZYDecoder *)decoder didChangeValueOfBuffering:(BOOL)buffering
{
    if (buffering) {
        self.state = ZYPlayerStateBuffering;
    } else {
        if (self.playing) {
            self.state = ZYPlayerStatePlaying;
        } else if (!self.prepareToken) {
            self.state = ZYPlayerStateReadyToPlay;
            self.prepareToken = YES;
        } else {
            self.state = ZYPlayerStateSuspend;
        }
    }
}

- (void)decoder:(ZYDecoder *)decoder didChangeValueOfBufferedDuration:(NSTimeInterval)bufferedDuration
{
    _playableTime = self.progress + bufferedDuration;
}

- (void)decoder:(ZYDecoder *)decoder didChangeValueOfProgress:(NSTimeInterval)progress
{
    self.progress = progress;
}

- (void)decoder:(ZYDecoder *)decoder didError:(NSError *)error {
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDecodeErrorKey object:self userInfo:@{kErrorKey : error}];
    
}

#pragma mark - ZYAudioManagerDelegate

- (void)audioManager:(ZYAudioManager *)audioManager outputData:(float *)outputData numberOfFrames:(UInt32)numberOfFrames numberOfChannels:(UInt32)numberOfChannels {
    
    if (!self.playing) {
        memset(outputData, 0, numberOfFrames * numberOfChannels * sizeof(float));
        return;
    }
    @autoreleasepool
    {
        while (numberOfFrames > 0)
        {
            if (!self.currentAudioFrame) {
                self.currentAudioFrame = [self.decoder getAudioFrame];
                [self.currentAudioFrame startPlaying];
            }
            if (!self.currentAudioFrame) {
                memset(outputData, 0, numberOfFrames * numberOfChannels * sizeof(float));
                return;
            }
            
            const Byte * bytes = (Byte *)self.currentAudioFrame->samples + self.currentAudioFrame->output_offset;
            const NSUInteger bytesLeft = self.currentAudioFrame->length - self.currentAudioFrame->output_offset;
            const NSUInteger frameSizeOf = numberOfChannels * sizeof(float);
            const NSUInteger bytesToCopy = MIN(numberOfFrames * frameSizeOf, bytesLeft);
            const NSUInteger framesToCopy = bytesToCopy / frameSizeOf;
            
            memcpy(outputData, bytes, bytesToCopy);
            numberOfFrames -= framesToCopy;
            outputData += framesToCopy * numberOfChannels;
            
            if (bytesToCopy < bytesLeft) {
                self.currentAudioFrame->output_offset += bytesToCopy;
            } else {
                [self.currentAudioFrame stopPlaying];
                self.currentAudioFrame = nil;
            }
        }
    }
    
}

@end
