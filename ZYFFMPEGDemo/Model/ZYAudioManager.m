//
//  ZYAudioManager.m
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/14.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import "ZYAudioManager.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>

static int const max_frame_size = 4096;
static int const max_chan = 2;

typedef struct {
    AUNode node;
    AudioUnit audioUnit;
} ZYAudioNodeContext;

typedef struct {
    AUGraph graph;
    ZYAudioNodeContext converterNodeContext;
    ZYAudioNodeContext mixerNodeContext;
    ZYAudioNodeContext outputNodeContext;
    AudioStreamBasicDescription commonDesc;
} ZYAudioOutputContext;

@interface ZYAudioManager ()

{
    float *_outData;
}

@property (assign, nonatomic) BOOL registed;
@property (assign, nonatomic) ZYAudioOutputContext *outputContext;
@property (strong, nonatomic) NSError *error;
@property (strong, nonatomic) NSError *warning;

@end

@implementation ZYAudioManager

+ (instancetype)shareInstance {
    static ZYAudioManager *_manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _manager = [self new];
    });
    return _manager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self->_outData = (float *)calloc(max_frame_size * max_chan, sizeof(float));
    }
    return self;
}

- (BOOL)registAudioSession {
    
    if (!self.registed) {
        self.registed = [self setupAudioUnit];
    }
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (error) {
        NSLog(@"Failed to active AudioSession: %@", error);
        return NO;
    }
    
    return self.registed;
    
}

- (BOOL)setupAudioUnit
{
    OSStatus result;
    UInt32 audioStreamBasicDescriptionSize = sizeof(AudioStreamBasicDescription);;
    
    self.outputContext = (ZYAudioOutputContext *)malloc(sizeof(ZYAudioOutputContext));
    memset(self.outputContext, 0, sizeof(ZYAudioOutputContext));
    
    result = NewAUGraph(&self.outputContext->graph);
    self.error = checkError(result, @"create  graph error");
    if (self.error) {
        [self delegateErrorCallback];
        return NO;
    }
    
    AudioComponentDescription converterDescription;
    converterDescription.componentType = kAudioUnitType_FormatConverter;
    converterDescription.componentSubType = kAudioUnitSubType_AUConverter;
    converterDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    result = AUGraphAddNode(self.outputContext->graph, &converterDescription, &self.outputContext->converterNodeContext.node);
    self.error = checkError(result, @"graph add converter node error");
    if (self.error) {
        [self delegateErrorCallback];
        return NO;
    }
    
    AudioComponentDescription mixerDescription;
    mixerDescription.componentType = kAudioUnitType_Mixer;
    mixerDescription.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    mixerDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    result = AUGraphAddNode(self.outputContext->graph, &mixerDescription, &self.outputContext->mixerNodeContext.node);
    self.error = checkError(result, @"graph add mixer node error");
    if (self.error) {
        [self delegateErrorCallback];
        return NO;
    }
    
    AudioComponentDescription outputDescription;
    outputDescription.componentType = kAudioUnitType_Output;
    outputDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    outputDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    result = AUGraphAddNode(self.outputContext->graph, &outputDescription, &self.outputContext->outputNodeContext.node);
    self.error = checkError(result, @"graph add output node error");
    if (self.error) {
        [self delegateErrorCallback];
        return NO;
    }
    
    result = AUGraphOpen(self.outputContext->graph);
    self.error = checkError(result, @"open graph error");
    if (self.error) {
        [self delegateErrorCallback];
        return NO;
    }
    
    result = AUGraphConnectNodeInput(self.outputContext->graph,
                                     self.outputContext->converterNodeContext.node,
                                     0,
                                     self.outputContext->mixerNodeContext.node,
                                     0);
    self.error = checkError(result, @"graph connect converter and mixer error");
    if (self.error) {
        [self delegateErrorCallback];
        return NO;
    }
    
    result = AUGraphConnectNodeInput(self.outputContext->graph,
                                     self.outputContext->mixerNodeContext.node,
                                     0,
                                     self.outputContext->outputNodeContext.node,
                                     0);
    self.error = checkError(result, @"graph connect converter and mixer error");
    if (self.error) {
        [self delegateErrorCallback];
        return NO;
    }
    
    result = AUGraphNodeInfo(self.outputContext->graph,
                             self.outputContext->converterNodeContext.node,
                             &converterDescription,
                             &self.outputContext->converterNodeContext.audioUnit);
    self.error = checkError(result, @"graph get converter audio unit error");
    if (self.error) {
        [self delegateErrorCallback];
        return NO;
    }
    
    result = AUGraphNodeInfo(self.outputContext->graph,
                             self.outputContext->mixerNodeContext.node,
                             &mixerDescription,
                             &self.outputContext->mixerNodeContext.audioUnit);
    self.error = checkError(result, @"graph get minxer audio unit error");
    if (self.error) {
        [self delegateErrorCallback];
        return NO;
    }
    
    result = AUGraphNodeInfo(self.outputContext->graph,
                             self.outputContext->outputNodeContext.node,
                             &outputDescription,
                             &self.outputContext->outputNodeContext.audioUnit);
    self.error = checkError(result, @"graph get output audio unit error");
    if (self.error) {
        [self delegateErrorCallback];
        return NO;
    }
    
    AURenderCallbackStruct converterCallback;
    converterCallback.inputProc = renderCallback;
    converterCallback.inputProcRefCon = (__bridge void *)(self);
    result = AUGraphSetNodeInputCallback(self.outputContext->graph,
                                         self.outputContext->converterNodeContext.node,
                                         0,
                                         &converterCallback);
    self.error = checkError(result, @"graph add converter input callback error");
    if (self.error) {
        [self delegateErrorCallback];
        return NO;
    }
    
    result = AudioUnitGetProperty(self.outputContext->outputNodeContext.audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input, 0,
                                  &self.outputContext->commonDesc,
                                  &audioStreamBasicDescriptionSize);
    self.warning = checkError(result, @"get hardware output stream format error");
    if (self.warning) {
        [self delegateWarningCallback];
    } else {
        if ([AVAudioSession sharedInstance].sampleRate != self.outputContext->commonDesc.mSampleRate) {
            self.outputContext->commonDesc.mSampleRate = [AVAudioSession sharedInstance].sampleRate;
            result = AudioUnitSetProperty(self.outputContext->outputNodeContext.audioUnit,
                                          kAudioUnitProperty_StreamFormat,
                                          kAudioUnitScope_Input,
                                          0,
                                          &self.outputContext->commonDesc,
                                          audioStreamBasicDescriptionSize);
            self.warning = checkError(result, @"set hardware output stream format error");
            if (self.warning) {
                [self delegateWarningCallback];
            }
        }
    }
    
    result = AudioUnitSetProperty(self.outputContext->converterNodeContext.audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  &self.outputContext->commonDesc,
                                  audioStreamBasicDescriptionSize);
    self.error = checkError(result, @"graph set converter input format error");
    if (self.error) {
        [self delegateErrorCallback];
        return NO;
    }
    
    result = AudioUnitSetProperty(self.outputContext->converterNodeContext.audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  0,
                                  &self.outputContext->commonDesc,
                                  audioStreamBasicDescriptionSize);
    self.error = checkError(result, @"graph set converter output format error");
    if (self.error) {
        [self delegateErrorCallback];
        return NO;
    }
    
    result = AudioUnitSetProperty(self.outputContext->mixerNodeContext.audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  &self.outputContext->commonDesc,
                                  audioStreamBasicDescriptionSize);
    self.error = checkError(result, @"graph set converter input format error");
    if (self.error) {
        [self delegateErrorCallback];
        return NO;
    }
    
    result = AudioUnitSetProperty(self.outputContext->mixerNodeContext.audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  0,
                                  &self.outputContext->commonDesc,
                                  audioStreamBasicDescriptionSize);
    self.error = checkError(result, @"graph set converter output format error");
    if (self.error) {
        [self delegateErrorCallback];
        return NO;
    }
    
    result = AudioUnitSetProperty(self.outputContext->mixerNodeContext.audioUnit,
                                  kAudioUnitProperty_MaximumFramesPerSlice,
                                  kAudioUnitScope_Global,
                                  0,
                                  &max_frame_size,
                                  sizeof(max_frame_size));
    self.warning = checkError(result, @"graph set mixer max frames per slice size error");
    if (self.warning) {
        [self delegateWarningCallback];
    }
    
    result = AUGraphInitialize(self.outputContext->graph);
    self.error = checkError(result, @"graph initialize error");
    if (self.error) {
        [self delegateErrorCallback];
        return NO;
    }
    
    return YES;
}

- (void)resignAudioSession
{
    if (self.registed) {
        self.registed = NO;
        OSStatus result = AUGraphUninitialize(self.outputContext->graph);
        self.warning = checkError(result, @"graph uninitialize error");
        if (self.warning) {
            [self delegateWarningCallback];
        }
        result = AUGraphClose(self.outputContext->graph);
        self.warning = checkError(result, @"graph close error");
        if (self.warning) {
            [self delegateWarningCallback];
        }
        result = DisposeAUGraph(self.outputContext->graph);
        self.warning = checkError(result, @"graph dispose error");
        if (self.warning) {
            [self delegateWarningCallback];
        }
        if (self.outputContext) {
            free(self.outputContext);
            self.outputContext = NULL;
        }
    }
    self->_playing = NO;
}

- (void)playWithDelegate:(id<ZYAudioManagerDelegate>)delegate {
    
    self.delegate = delegate;
    [self play];
    
}

- (void)play {
    
    if (!_playing) {
        if ([self registAudioSession]) {
            OSStatus result = AUGraphStart(self.outputContext->graph);
            if (result != noErr) {
                NSLog(@"graph start error");
            } else {
                _playing = YES;
            }
        }
    }
    
}

- (void)pause
{
    if (_playing) {
        OSStatus result = AUGraphStop(self.outputContext->graph);
        if (result != noErr) {
            NSLog(@"graph pause error");
        }
        _playing = NO;
    }
}

#pragma mark - getter

- (Float64)samplingRate
{
    if (!self.registed) {
        return 0;
    }
    Float64 number = self.outputContext->commonDesc.mSampleRate;
    if (number > 0) {
        return number;
    }
    return (Float64)[AVAudioSession sharedInstance].sampleRate;
}

- (UInt32)numberOfChannels
{
    if (!self.registed) {
        return 0;
    }
    UInt32 number = self.outputContext->commonDesc.mChannelsPerFrame;
    if (number > 0) {
        return number;
    }
    return (UInt32)[AVAudioSession sharedInstance].outputNumberOfChannels;
}

- (OSStatus)renderWithFrames:(UInt32)inNumberFrames ioData:(AudioBufferList *)ioData {
    if (!self.registed) {
        return noErr;
    }
    
    for (int iBuffer = 0; iBuffer < ioData->mNumberBuffers; iBuffer++) {
        memset(ioData->mBuffers[iBuffer].mData, 0, ioData->mBuffers[iBuffer].mDataByteSize);
    }
    
    if (self.playing && self.delegate)
    {
        [self.delegate audioManager:self outputData:self->_outData numberOfFrames:inNumberFrames numberOfChannels:self.numberOfChannels];
        
        UInt32 numBytesPerSample = self.outputContext->commonDesc.mBitsPerChannel / 8;
        if (numBytesPerSample == 4) {
            float zero = 0.0;
            for (int iBuffer = 0; iBuffer < ioData->mNumberBuffers; iBuffer++) {
                int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
                for (int iChannel = 0; iChannel < thisNumChannels; iChannel++) {
                    vDSP_vsadd(self->_outData + iChannel,
                               self.numberOfChannels,
                               &zero,
                               (float *)ioData->mBuffers[iBuffer].mData,
                               thisNumChannels,
                               inNumberFrames);
                }
            }
        }
        else if (numBytesPerSample == 2)
        {
            float scale = (float)INT16_MAX;
            vDSP_vsmul(self->_outData, 1, &scale, self->_outData, 1, inNumberFrames * self.numberOfChannels);
            
            for (int iBuffer = 0; iBuffer < ioData->mNumberBuffers; iBuffer++) {
                int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
                for (int iChannel = 0; iChannel < thisNumChannels; iChannel++) {
                    vDSP_vfix16(self->_outData + iChannel,
                                self.numberOfChannels,
                                (SInt16 *)ioData->mBuffers[iBuffer].mData + iChannel,
                                thisNumChannels,
                                inNumberFrames);
                }
            }
        }
    }
    
    return noErr;
}

- (void)delegateErrorCallback
{
    if (self.error) {
        NSLog(@"ZYAudioManager did error : %@", self.error);
    }
}

- (void)delegateWarningCallback
{
    if (self.warning) {
        NSLog(@"SGAudioManager did warning : %@", self.warning);
    }
}

static NSError * checkError(OSStatus result, NSString * domain)
{
    if (result == noErr) return nil;
    NSError * error = [NSError errorWithDomain:domain code:result userInfo:nil];
    return error;
}

static OSStatus renderCallback(void * inRefCon,
                               AudioUnitRenderActionFlags * ioActionFlags,
                               const AudioTimeStamp * inTimeStamp,
                               UInt32 inOutputBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList * ioData)
{
    ZYAudioManager * manager = (__bridge ZYAudioManager *)inRefCon;
    return [manager renderWithFrames:inNumberFrames ioData:ioData];
}

- (void)dealloc
{
    [self resignAudioSession];
    if (self->_outData) {
        free(self->_outData);
        self->_outData = NULL;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"%s", __func__);
}

@end
