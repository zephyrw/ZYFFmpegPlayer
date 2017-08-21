//
//  ZYProgramYUV420.h
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/10.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import <GLKit/GLKit.h>

@class ZYVideoFrame;

static int const index_count = 6;

@interface ZYProgramYUV420 : NSObject

+ (instancetype)program;

/**
 让program生效
 */
- (void)use;

/**
 更新modelViewPortriat坐标

 @param matrix mvp矩阵
 */
- (void)updateMatrix:(GLKMatrix4)matrix;


/**
 获取变量位置
 */
- (void)setupVariable;

/**
 使绑定的变量值生效
 */
- (void)bindVariable;

/**
 通过videoFrame生成三个图片纹理

 @param videoFrame 储存视频原始数据的模型
 @param aspect 视频比例指针
 @return 纹理是否更新成功
 */
- (BOOL)updateTextureWithGLFrame:(ZYVideoFrame *)videoFrame aspect:(CGFloat *)aspect;

/**
 缓存和绑定元素坐标、顶点坐标和纹理坐标
 */
- (void)bindBuffer;

@end
