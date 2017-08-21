//
//  ZYDisplayView.h
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/10.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZYPlayer.h"

typedef NS_ENUM(NSInteger, ZYDisplayRendererType) {
    ZYDisplayRendererTypeAVPlayerlayer = 0,
    ZYDisplayRendererTypeOpenGL,
    ZYDisplayRendererTypeEmpty
};

@interface ZYDisplayView : UIView

/**
 渲染类型
 */
@property (assign, nonatomic) ZYDisplayRendererType rendererType;

/**
 播放器
 */
@property (weak, nonatomic, readonly) ZYPlayer *abstractPlayer;

/**
 初始化显示层
 */
+ (instancetype)displayViewWithAbstractPlayer:(ZYPlayer *)player;

/**
 清空渲染界面
 */
- (void)rendererWithTypeEmpty;

/**
 用avplayerLayer显示内容
 */
- (void)rendererWithTypeAVPlayerLayer;

/**
 用OpenGL渲染界面
 */
- (void)rendererWithTypeOpenGL;

/**
 更新缩放模式
 */
- (void)reloadGravityMode;

@end
