//
//  ZYDisplayView.m
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/10.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import "ZYDisplayView.h"
#import "ZYGLViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ZYDisplayView ()

@property (strong, nonatomic) AVPlayerLayer *avplayerLayer;
@property (strong, nonatomic) ZYGLViewController *glViewController;
@property (assign, nonatomic) BOOL avplayerLayerToken;

@end

@implementation ZYDisplayView

+ (instancetype)displayViewWithAbstractPlayer:(ZYPlayer *)player {
    
    return [[self alloc] initWithAbstractPlayer:player];
    
}

- (instancetype)initWithAbstractPlayer:(ZYPlayer *)player {
    
    if (self = [super init]) {
        _abstractPlayer = player;
    }
    
    return self;
    
}

- (void)rendererWithTypeEmpty
{
    if (self.rendererType != ZYDisplayRendererTypeEmpty) {
        self->_rendererType = ZYDisplayRendererTypeEmpty;
        [self reloadView];
    }
}

- (void)rendererWithTypeAVPlayerLayer
{
    if (self.rendererType != ZYDisplayRendererTypeAVPlayerlayer) {
        self.rendererType = ZYDisplayRendererTypeAVPlayerlayer;
        [self reloadView];
    }
}

- (void)rendererWithTypeOpenGL
{
    if (self.rendererType != ZYDisplayRendererTypeOpenGL) {
        self->_rendererType = ZYDisplayRendererTypeOpenGL;
        [self reloadView];
    }
}

- (void)reloadView {
    
    [self cleanView];
    switch (self.rendererType) {
        case ZYDisplayRendererTypeEmpty:
            break;
        case ZYDisplayRendererTypeAVPlayerlayer:
        {
            self.avplayerLayer = [AVPlayerLayer playerLayerWithPlayer:nil];
//            [self reloadPlayerConfig];
            self.avplayerLayerToken = NO;
            [self.layer insertSublayer:self.avplayerLayer atIndex:0];
//            [self reloadGravityMode];
        }
            break;
        case ZYDisplayRendererTypeOpenGL:
        {
            self.glViewController = [ZYGLViewController viewControllerWithDisplayView:self];
            dispatch_async(dispatch_get_main_queue(), ^{
                GLKView * glView = (GLKView *)self.glViewController.view;
                [self insertSubview:glView atIndex:0];
            });
        }
            break;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateDisplayViewLayout:self.bounds];
    });
    
}

- (void)reloadGravityMode
{
    if (self.avplayerLayer) {
        switch (self.abstractPlayer.viewGravityMode) {
            case ZYGravityModeResize:
                self.avplayerLayer.videoGravity = AVLayerVideoGravityResize;
                break;
            case ZYGravityModeResizeAspect:
                self.avplayerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
                break;
            case ZYGravityModeResizeAspectFill:
                self.avplayerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
                break;
        }
    }
}

- (void)updateDisplayViewLayout:(CGRect)frame
{
    if (self.avplayerLayer) {
        self.avplayerLayer.frame = frame;
        if (self.abstractPlayer.viewAnimationHidden || !self.avplayerLayerToken) {
            [self.avplayerLayer removeAllAnimations];
            self.avplayerLayerToken = YES;
        }
    }
    if (self.glViewController) {
        [self.glViewController reloadViewport];
    }
}

- (void)cleanView
{
    if (self.avplayerLayer) {
        [self.avplayerLayer removeFromSuperlayer];
        self.avplayerLayer.player = nil;
        self.avplayerLayer = nil;
    }
    if (self.glViewController) {
        GLKView * glView = (GLKView *)self.glViewController.view;
        [glView removeFromSuperview];
        self.glViewController = nil;
    }
    self.avplayerLayerToken = NO;
}

- (void)dealloc {
    [self cleanView];
    NSLog(@"%s", __func__);
}

@end
