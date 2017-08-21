//
//  ZYAudioFrame.m
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/11.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import "ZYAudioFrame.h"

@implementation ZYAudioFrame

{
    size_t buffer_size;
}

- (ZYFrameType)type
{
    return ZYFrameTypeAudio;
}

- (int)size
{
    return (int)self->length;
}

- (void)setSamplesLength:(NSUInteger)samplesLength
{
    if (self->buffer_size < samplesLength) {
        if (self->buffer_size > 0 && self->samples != NULL) {
            free(self->samples);
        }
        self->buffer_size = samplesLength;
        self->samples = malloc(self->buffer_size);
    }
    self->length = (int)samplesLength;
    self->output_offset = 0;
}

- (void)dealloc
{
    if (self->buffer_size > 0 && self->samples != NULL) {
        free(self->samples);
    }
//    NSLog(@"%s", __func__);
}

@end
