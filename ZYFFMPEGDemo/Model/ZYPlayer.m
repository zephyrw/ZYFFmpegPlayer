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

@interface ZYPlayer () <ZYDecoderDelegate>

@property (strong, nonatomic) ZYDisplayView *displayView;

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
    }
    return self;
}

- (void)replaceVideoWithURL:(NSURL *)videoURL {
    
    [self clean];
    self.decoder = [ZYDecoder decoderWithVideoURL:videoURL];
    self.decoder.delegate = self;
    
}

- (void)clean {
    
    [self cleanDecoder];
    [self cleanFrame];
    [self cleanPlayer];
    
}

- (void)cleanDecoder {
    
    if (self.decoder) {
        [self.decoder closeFile];
        self.decoder = nil;
    }
    
}

- (void)cleanFrame {
    
}

- (void)cleanPlayer {
    
    [self.displayView rendererWithTypeEmpty];
    
}

- (UIView *)view {
    
    return self.displayView;
    
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

- (void)decoderDidPrepareToDecodeFrames {
    
    [self.displayView rendererWithTypeOpenGL];
    
}

@end
