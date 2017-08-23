//
//  ZYGLViewController.m
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/10.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import "ZYGLViewController.h"
#import "ZYProgramYUV420.h"
#import "ZYVideoFrame.h"
#import "ZYDecoder.h"
#import "ZYDisplayView.h"

@interface ZYGLViewController ()

@property (strong, nonatomic) NSLock *openGLLock;
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) ZYProgramYUV420 *program;
@property (strong, nonatomic) ZYVideoFrame *currentFrame;
@property (nonatomic, assign) CGRect viewport;
@property (strong, nonatomic) ZYDisplayView *displayView;
@property (nonatomic, assign) CGFloat aspect;
@property (assign, nonatomic) BOOL drawToekn;

@end

@implementation ZYGLViewController

+ (instancetype)viewControllerWithDisplayView:(ZYDisplayView *)displayView {
    
    return [[ZYGLViewController alloc] initWithDisplayView:displayView];;
    
}

- (instancetype)initWithDisplayView:(ZYDisplayView *)displayView {
    
    if (self = [super init]) {
        self.displayView = displayView;
    }
    return self;
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupOpenGL];
    
}

- (void)setupOpenGL {
    
    self.openGLLock = [[NSLock alloc] init];
    GLKView *glView = (GLKView *)self.view;
    glView.backgroundColor = [UIColor blackColor];
    
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!context) {
        NSLog(@"Failed to create context");
        return;
    }
    self.context = context;
    glView.context = context;
    
    [EAGLContext setCurrentContext:context];
    
    glView.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    glView.contentScaleFactor = [UIScreen mainScreen].scale;
    
    self.program = [ZYProgramYUV420 program];
    
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    
    [self.openGLLock lock];
    
    [EAGLContext setCurrentContext:self.context];
    
    if ([self needDrawOpenGL]) {
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
            [self.openGLLock unlock];
            return;
        }
        GLKView * glView = (GLKView *)self.view;
        self.viewport = glView.bounds;
        [self drawOpenGL];
    }
    [self.openGLLock unlock];
    
}

- (void)setAspect:(CGFloat)aspect
{
    if (_aspect != aspect) {
        _aspect = aspect;
        [self reloadViewport];
    }
}

- (void)reloadViewport {
    
    GLKView * glView = (GLKView *)self.view;
    CGRect superviewFrame = glView.superview.bounds;
    CGFloat superviewAspect = superviewFrame.size.width / superviewFrame.size.height;
    
    if (self.aspect <= 0) {
        glView.frame = superviewFrame;
        return;
    }
    
    CGFloat resultAspect = self.aspect;
    switch (self.currentFrame.rotateType) {
        case SGFFVideoFrameRotateType90:
        case SGFFVideoFrameRotateType270:
            resultAspect = 1 / self.aspect;
            break;
        case SGFFVideoFrameRotateType0:
        case SGFFVideoFrameRotateType180:
            break;
    }
    
    ZYGravityMode gravityMode = self.displayView.abstractPlayer.viewGravityMode;
    switch (gravityMode) {
        case ZYGravityModeResize:
            glView.frame = superviewFrame;
            break;
        case ZYGravityModeResizeAspect:
            if (superviewAspect < resultAspect) {
                CGFloat height = superviewFrame.size.width / resultAspect;
                glView.frame = CGRectMake(0, (superviewFrame.size.height - height) / 2, superviewFrame.size.width, height);
            } else if (superviewAspect > resultAspect) {
                CGFloat width = superviewFrame.size.height * resultAspect;
                glView.frame = CGRectMake((superviewFrame.size.width - width) / 2, 0, width, superviewFrame.size.height);
            } else {
                glView.frame = superviewFrame;
            }
            break;
        case ZYGravityModeResizeAspectFill:
            if (superviewAspect < resultAspect) {
                CGFloat width = superviewFrame.size.height * resultAspect;
                glView.frame = CGRectMake(-(width - superviewFrame.size.width) / 2, 0, width, superviewFrame.size.height);
            } else if (superviewAspect > resultAspect) {
                CGFloat height = superviewFrame.size.width / resultAspect;
                glView.frame = CGRectMake(0, -(height - superviewFrame.size.height) / 2, superviewFrame.size.width, height);
            } else {
                glView.frame = superviewFrame;
            }
            break;
        default:
            glView.frame = superviewFrame;
            break;
    }
    self.drawToekn = NO;
    
}

- (BOOL)needDrawOpenGL {
    
    self.currentFrame = [self.displayView.abstractPlayer.decoder getVideoFrameWithCurrentPosition:self.currentFrame.position currentDuration:self.currentFrame.duration];
    [self.currentFrame startPlaying];
    if (self.currentFrame.size < 0) {
        return NO;
    }
    
    CGFloat aspect = _aspect > 0 ? _aspect : 16.0 / 9.0;
    [self.program updateTextureWithGLFrame:self.currentFrame aspect:&aspect];
    if (self.aspect != aspect) {
        self.aspect = aspect;
    }
    
    return YES;
    
}

- (void)drawOpenGL {
    
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    
    [self.program use];
    [self.program bindVariable];
    
    CGFloat scale = [UIScreen mainScreen].scale;
    CGRect rect = CGRectMake(0, 0, self.viewport.size.width * scale, self.viewport.size.height * scale);
    [self.program bindBuffer];
    glViewport(rect.origin.x, rect.origin.y, CGRectGetWidth(rect), CGRectGetHeight(rect));
    [self.program updateMatrix:GLKMatrix4Identity];
    glDrawElements(GL_TRIANGLES, index_count, GL_UNSIGNED_SHORT, 0);
    
}

- (void)dealloc {
    NSLog(@"ZYGLViewController dealloc");
    [EAGLContext setCurrentContext:nil];
}

@end
