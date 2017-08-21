//
//  ZYAudioFrame.h
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/11.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZYFFFrame.h"

@interface ZYAudioFrame : ZYFFFrame

{
@public
    float * samples;
    int length;
    int output_offset;
}

- (void)setSamplesLength:(NSUInteger)samplesLength;

@end
