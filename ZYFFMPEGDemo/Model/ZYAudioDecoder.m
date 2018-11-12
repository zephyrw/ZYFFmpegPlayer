//
//  ZYAudioDecoder.m
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/11.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import "ZYAudioDecoder.h"
#import "ZYAudioFrame.h"
#import "avformat.h"
#import "swscale.h"
#import "swresample.h"
#import "ZYFrameQueue.h"
#import <Accelerate/Accelerate.h>
#import "ZYAudioManager.h"

@interface ZYAudioDecoder ()

{
    AVFrame * _temp_frame;
    AVCodecContext *_codec_context;
    
    Float64 _samplingRate;
    UInt32 _channelCount;
    
    SwrContext * _audio_swr_context;
    void * _audio_swr_buffer;
    int _audio_swr_buffer_size;
}

@property (assign, nonatomic) double timebase;
@property (strong, nonatomic) ZYFrameQueue *frameQueue;

@end

@implementation ZYAudioDecoder

+ (instancetype)audioDecoderWithCodecContext:(AVCodecContext *)codecContext timeBase:(NSTimeInterval)timeBase {
    
    return [[self alloc] initWithCodecContext:codecContext timeBase:timeBase];
    
}

- (instancetype)initWithCodecContext:(AVCodecContext *)codecContext timeBase:(NSTimeInterval)timeBase
{
    self = [super init];
    if (self) {
        self->_codec_context = codecContext;
        self.timebase = timeBase;
        self->_temp_frame = av_frame_alloc();
        self.frameQueue = [ZYFrameQueue audioQueue];
        [self setupSwsContext];
    }
    return self;
}

- (void)setupSwsContext
{
    [self updateAudioOutputInfo];
    
    _audio_swr_context = swr_alloc_set_opts(NULL,
                                            av_get_default_channel_layout(_channelCount), AV_SAMPLE_FMT_S16, _samplingRate,
                                            av_get_default_channel_layout(_codec_context->channels), _codec_context->sample_fmt, _codec_context->sample_rate,
                                            0,
                                            NULL);
    
    int result = swr_init(_audio_swr_context);
    if (result < 0 || !_audio_swr_context) {
        if (_audio_swr_context) {
            swr_free(&_audio_swr_context);
        }
    }
}

- (BOOL)decodePacket:(AVPacket)packet
{
    if (packet.data == NULL) return NO;
    
    int result = avcodec_send_packet(_codec_context, &packet);
    if (result < 0 && result != AVERROR(EAGAIN) && result != AVERROR_EOF) {
        return NO;
    }
    
    while (result >= 0) {
        result = avcodec_receive_frame(_codec_context, _temp_frame);
        if (result < 0) {
            if (result != AVERROR(EAGAIN) && result != AVERROR_EOF) {
                return NO;
            }
            break;
        }
        @autoreleasepool
        {
            ZYAudioFrame * frame = [self decode:packet.size];
            if (frame) {
                [self.frameQueue putFrame:frame];
            }
        }
    }
    av_packet_unref(&packet);
    return YES;
}

- (ZYAudioFrame *)decode:(int)packetSize
{
    if (!_temp_frame->data[0]) return nil;
    
    [self updateAudioOutputInfo];
    
    int numberOfFrames;
    void * audioDataBuffer;
    
    if (_audio_swr_context) {
        const int ratio = MAX(1, _samplingRate / _codec_context->sample_rate) * MAX(1, _channelCount / _codec_context->channels) * 2;
        const int buffer_size = av_samples_get_buffer_size(NULL, _channelCount, _temp_frame->nb_samples * ratio, AV_SAMPLE_FMT_S16, 1);
        
        if (!_audio_swr_buffer || _audio_swr_buffer_size < buffer_size) {
            _audio_swr_buffer_size = buffer_size;
            _audio_swr_buffer = realloc(_audio_swr_buffer, _audio_swr_buffer_size);
        }
        
        Byte * outyput_buffer[2] = {_audio_swr_buffer, 0};
        numberOfFrames = swr_convert(_audio_swr_context, outyput_buffer, _temp_frame->nb_samples * ratio, (const uint8_t **)_temp_frame->data, _temp_frame->nb_samples);
        if (numberOfFrames < 0) {
            NSLog(@"audio codec error: numberOfFrames -> %d", numberOfFrames);
            return nil;
        }
        audioDataBuffer = _audio_swr_buffer;
    } else {
        if (_codec_context->sample_fmt != AV_SAMPLE_FMT_S16) {
            NSLog(@"%s:audio format error", __func__);
            return nil;
        }
        audioDataBuffer = _temp_frame->data[0];
        numberOfFrames = _temp_frame->nb_samples;
    }
    
    ZYAudioFrame * audioFrame = [self.frameQueue getUnuseFrame];
    audioFrame.packetSize = packetSize;
    audioFrame.position = av_frame_get_best_effort_timestamp(_temp_frame) * _timebase;
    audioFrame.duration = av_frame_get_pkt_duration(_temp_frame) * _timebase;
    
    if (audioFrame.duration == 0) {
        audioFrame.duration = audioFrame->length / (sizeof(float) * _channelCount * _samplingRate);
    }
    
    const NSUInteger numberOfElements = numberOfFrames * self->_channelCount;
    [audioFrame setSamplesLength:numberOfElements * sizeof(float)];
    
    float scale = 1.0 / (float)INT16_MAX ;
    vDSP_vflt16((SInt16 *)audioDataBuffer, 1, audioFrame->samples, 1, numberOfElements);
    vDSP_vsmul(audioFrame->samples, 1, &scale, audioFrame->samples, 1, numberOfElements);
    
    return audioFrame;
}

- (ZYAudioFrame *)getFrameSync {
    return [self.frameQueue getFrameSync];
}

- (void)updateAudioOutputInfo {
    
    _channelCount = [ZYAudioManager shareInstance].numberOfChannels;
    _samplingRate = [ZYAudioManager shareInstance].samplingRate;
    
}

- (void)flush {
//    NSLog(@"Realese audio decoder");
    [self.frameQueue flush];
    [self.frameQueue flushFramePool];
    if (_codec_context) {
        avcodec_flush_buffers(_codec_context);
    }
}

- (void)destroy {
    [self.frameQueue destroy];
    [self.frameQueue flushFramePool];
}

- (void)destroyAudioTrack {
    
    if (_codec_context)
    {
        avcodec_close(_codec_context);
        avcodec_free_context(&_codec_context);
        _codec_context = NULL;
    }
    
}

- (BOOL)empty {
    return self.frameQueue.count <= 0;
}

- (int)size {
    return self.frameQueue.packetSize;
}

- (NSTimeInterval)duration {
    return self.frameQueue.duration;
}

- (void)dealloc
{
    if (_audio_swr_buffer) {
        free(_audio_swr_buffer);
        _audio_swr_buffer = NULL;
        _audio_swr_buffer_size = 0;
    }
    if (_audio_swr_context) {
        swr_free(&_audio_swr_context);
        _audio_swr_context = NULL;
    }
    if (_temp_frame) {
        av_frame_free(&_temp_frame);
        _temp_frame = NULL;
    }
    NSLog(@"%s", __func__);
}

@end
