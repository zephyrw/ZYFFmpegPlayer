//
//  ZYGLViewController.h
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/10.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import <GLKit/GLKit.h>

@class ZYDisplayView;

@interface ZYGLViewController : GLKViewController

+ (instancetype)viewControllerWithDisplayView:(ZYDisplayView *)displayView;

- (void)reloadViewport;

@end
