//
//  ZYVideoFrame.m
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/8.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import "ZYVideoFrame.h"
#import "avformat.h"
#import "swscale.h"
#import "imgutils.h"

@interface ZYVideoFrame()

@property (strong, nonatomic) NSLock *lock;

@end

@implementation ZYVideoFrame
{
    enum AVPixelFormat pixelFormat;
    
    int channel_lenghts[SGYUVChannelCount];
    int channel_linesize[SGYUVChannelCount];
    size_t channel_pixels_buffer_size[SGYUVChannelCount];
}

+ (instancetype)videoFrame
{
    return [[self alloc] init];
}

- (ZYFrameType)type {
    return ZYFrameTypeVideo;
}

- (instancetype)init
{
    if (self = [super init]) {
        channel_lenghts[SGYUVChannelLuma] = 0;
        channel_lenghts[SGYUVChannelChromaB] = 0;
        channel_lenghts[SGYUVChannelChromaR] = 0;
        channel_pixels_buffer_size[SGYUVChannelLuma] = 0;
        channel_pixels_buffer_size[SGYUVChannelChromaB] = 0;
        channel_pixels_buffer_size[SGYUVChannelChromaR] = 0;
        channel_linesize[SGYUVChannelLuma] = 0;
        channel_linesize[SGYUVChannelChromaB] = 0;
        channel_linesize[SGYUVChannelChromaR] = 0;
        channel_pixels[SGYUVChannelLuma] = NULL;
        channel_pixels[SGYUVChannelChromaB] = NULL;
        channel_pixels[SGYUVChannelChromaR] = NULL;
        self.lock = [[NSLock alloc] init];
    }
    return self;
}

- (void)setFrameData:(AVFrame *)frame width:(int)width height:(int)height
{
    pixelFormat = frame->format;
    
    self->_width = width;
    self->_height = height;
    
    int linesize_y = frame->linesize[SGYUVChannelLuma];
    int linesize_u = frame->linesize[SGYUVChannelChromaB];
    int linesize_v = frame->linesize[SGYUVChannelChromaR];
    
    channel_linesize[SGYUVChannelLuma] = linesize_y;
    channel_linesize[SGYUVChannelChromaB] = linesize_u;
    channel_linesize[SGYUVChannelChromaR] = linesize_v;
    
    UInt8 * buffer_y = channel_pixels[SGYUVChannelLuma];
    UInt8 * buffer_u = channel_pixels[SGYUVChannelChromaB];
    UInt8 * buffer_v = channel_pixels[SGYUVChannelChromaR];
    
    size_t buffer_size_y = channel_pixels_buffer_size[SGYUVChannelLuma];
    size_t buffer_size_u = channel_pixels_buffer_size[SGYUVChannelChromaB];
    size_t buffer_size_v = channel_pixels_buffer_size[SGYUVChannelChromaR];
    
    int need_size_y = SGYUVChannelFilterNeedSize(linesize_y, width, height, 1);
    channel_lenghts[SGYUVChannelLuma] = need_size_y;
    if (buffer_size_y < need_size_y) {
        if (buffer_size_y > 0 && buffer_y != NULL) {
            free(buffer_y);
        }
        channel_pixels_buffer_size[SGYUVChannelLuma] = need_size_y;
        channel_pixels[SGYUVChannelLuma] = malloc(need_size_y);
    }
    int need_size_u = SGYUVChannelFilterNeedSize(linesize_u, width / 2, height / 2, 1);
    channel_lenghts[SGYUVChannelChromaB] = need_size_u;
    if (buffer_size_u < need_size_u) {
        if (buffer_size_u > 0 && buffer_u != NULL) {
            free(buffer_u);
        }
        channel_pixels_buffer_size[SGYUVChannelChromaB] = need_size_u;
        channel_pixels[SGYUVChannelChromaB] = malloc(need_size_u);
    }
    int need_size_v = SGYUVChannelFilterNeedSize(linesize_v, width / 2, height / 2, 1);
    channel_lenghts[SGYUVChannelChromaR] = need_size_v;
    if (buffer_size_v < need_size_v) {
        if (buffer_size_v > 0 && buffer_v != NULL) {
            free(buffer_v);
        }
        channel_pixels_buffer_size[SGYUVChannelChromaR] = need_size_v;
        channel_pixels[SGYUVChannelChromaR] = malloc(need_size_v);
    }
    
    SGYUVChannelFilter(frame->data[SGYUVChannelLuma],
                       linesize_y,
                       width,
                       height,
                       channel_pixels[SGYUVChannelLuma],
                       channel_pixels_buffer_size[SGYUVChannelLuma],
                       1);
    SGYUVChannelFilter(frame->data[SGYUVChannelChromaB],
                       linesize_u,
                       width / 2,
                       height / 2,
                       channel_pixels[SGYUVChannelChromaB],
                       channel_pixels_buffer_size[SGYUVChannelChromaB],
                       1);
    SGYUVChannelFilter(frame->data[SGYUVChannelChromaR],
                       linesize_v,
                       width / 2,
                       height / 2,
                       channel_pixels[SGYUVChannelChromaR],
                       channel_pixels_buffer_size[SGYUVChannelChromaR],
                       1);
}

- (void)stopPlaying
{
    [self.lock lock];
    [super stopPlaying];
    [self.lock unlock];
}

- (UIImage *)image
{
    [self.lock lock];
    UIImage * image = SGYUVConvertToImage(channel_pixels, channel_linesize, self.width, self.height, pixelFormat);
    [self.lock unlock];
    return image;
}

- (int)size
{
    return (int)(channel_lenghts[SGYUVChannelLuma] + channel_lenghts[SGYUVChannelChromaB] + channel_lenghts[SGYUVChannelChromaR]);
}

- (void)dealloc
{
    if (channel_pixels[SGYUVChannelLuma] != NULL && channel_pixels_buffer_size[SGYUVChannelLuma] > 0) {
        free(channel_pixels[SGYUVChannelLuma]);
    }
    if (channel_pixels[SGYUVChannelChromaB] != NULL && channel_pixels_buffer_size[SGYUVChannelChromaB] > 0) {
        free(channel_pixels[SGYUVChannelChromaB]);
    }
    if (channel_pixels[SGYUVChannelChromaR] != NULL && channel_pixels_buffer_size[SGYUVChannelChromaR] > 0) {
        free(channel_pixels[SGYUVChannelChromaR]);
    }
//    NSLog(@"%s", __func__);
}

UIImage * SGYUVConvertToImage(UInt8 * src_data[], int src_linesize[], int width, int height, enum AVPixelFormat pixelFormat)
{
    struct SwsContext * sws_context = NULL;
    sws_context = sws_getCachedContext(sws_context,
                                       width,
                                       height,
                                       pixelFormat,
                                       width,
                                       height,
                                       AV_PIX_FMT_RGB24,
                                       SWS_FAST_BILINEAR,
                                       NULL, NULL, NULL);
    if (!sws_context) return nil;
    
    uint8_t * data[AV_NUM_DATA_POINTERS];
    int linesize[AV_NUM_DATA_POINTERS];
    
    int result = av_image_alloc(data, linesize, width, height, AV_PIX_FMT_RGB24, 1);
    if (result < 0) {
        if (sws_context) {
            sws_freeContext(sws_context);
        }
        return nil;
    }
    
    result = sws_scale(sws_context, (const uint8_t **)src_data, src_linesize, 0, height, data, linesize);
    if (sws_context) {
        sws_freeContext(sws_context);
    }
    if (result < 0) return nil;
    if (linesize[0] <= 0 || data[0] == NULL) return nil;
    
    UIImage * image = SGPLFImageWithRGBData(data[0], linesize[0], width, height);
    av_freep(&data[0]);
    
    return image;
}

UIImage * SGPLFImageWithRGBData(UInt8 * rgb_data, int linesize, int width, int height)
{
    CGImageRef imageRef = SGPLFImageCGImageWithRGBData(rgb_data, linesize, width, height);
    if (!imageRef) return nil;
    UIImage * image = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    return image;
}

CGImageRef SGPLFImageCGImageWithRGBData(UInt8 * rgb_data, int linesize, int width, int height)
{
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, rgb_data, linesize * height);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef imageRef = CGImageCreate(width,
                                        height,
                                        8,
                                        24,
                                        linesize,
                                        colorSpace,
                                        kCGBitmapByteOrderDefault,
                                        provider,
                                        NULL,
                                        NO,
                                        kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    CFRelease(data);
    
    return imageRef;
}

int SGYUVChannelFilterNeedSize(int linesize, int width, int height, int channel_count)
{
    width = MIN(linesize, width);
    return width * height * channel_count;
}

void SGYUVChannelFilter(UInt8 * src, int linesize, int width, int height, UInt8 * dst, size_t dstsize, int channel_count)
{
    width = MIN(linesize, width);
    UInt8 * temp = dst;
    memset(dst, 0, dstsize);
    for (int i = 0; i < height; i++) {
        memcpy(temp, src, width * channel_count);
        temp += (width * channel_count);
        src += linesize;
    }
}

@end
