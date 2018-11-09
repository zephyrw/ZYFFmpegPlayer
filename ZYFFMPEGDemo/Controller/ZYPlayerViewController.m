//
//  ZYPlayerViewController.m
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/10.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import "ZYPlayerViewController.h"
#import "ZYPlayer.h"

@interface ZYPlayerViewController ()

@property (strong, nonatomic) ZYPlayer *player;
@property (weak, nonatomic) IBOutlet UILabel *currentTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *totalTimeLabel;
@property (weak, nonatomic) IBOutlet UISlider *slider;
@property (weak, nonatomic) IBOutlet UILabel *stateLabel;

@end

@implementation ZYPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    self.slider.value = 0;
    [self startPlay];
    
}

- (void)startPlay {
    
    self.player = [ZYPlayer player];
    [self.view insertSubview:self.player.view atIndex:0];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stateAction:) name:kNotificationPlayerStateChangeKey object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(progressChanged:) name:kNotificationPlayerProgressChangeKey object:nil]; 
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(decodeError:) name:kNotificationDecodeErrorKey object:nil];
    [self.player replaceVideoWithURL:self.fileURL];
    
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    self.player.view.frame = self.view.bounds;
}

- (IBAction)playButtonClick:(UIButton *)sender {
    [self.player play];
}

- (IBAction)pauseButtonClick:(UIButton *)sender {
    [self.player pause];
}

- (void)stateAction:(NSNotification *)noti {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        ZYPlayerState state = [[noti.userInfo objectForKey:kCurrentKey] integerValue];
        NSString * text;
        switch (state) {
            case ZYPlayerStateNone:
                text = @"None";
                break;
            case ZYPlayerStateBuffering:
                text = @"Buffering...";
                break;
            case ZYPlayerStateReadyToPlay:
                text = @"Prepare";
                self.totalTimeLabel.text = [self timeStringFromSeconds:self.player.duration];
                [self.player play];
                break;
            case ZYPlayerStatePlaying:
                text = @"Playing";
                break;
            case ZYPlayerStateSuspend:
                text = @"Suspend";
                break;
            case ZYPlayerStateFinished:
                text = @"Finished";
                break;
            case ZYPlayerStateFailed:
                text = @"Error";
                break;
        }
        self.stateLabel.text = text;
    });
}
- (IBAction)sliderTouchDown:(UISlider *)sender {
    [self.player pause];
}

- (void)progressChanged:(NSNotification *)noti {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.slider.value = [[noti.userInfo objectForKey:kPercentKey] doubleValue];
        self.currentTimeLabel.text = [self timeStringFromSeconds:[[noti.userInfo objectForKey:kCurrentKey] doubleValue]];
//        NSLog(@"%f", self.slider.value);
    });
    
}

- (IBAction)sliderValueChanged:(UISlider *)sender {
    
}

- (IBAction)sliderTouchUp:(UISlider *)sender {
    [self.player play];
}

- (void)decodeError:(NSNotification *)noti {
    
    NSLog(@"%@", [noti.userInfo objectForKey:kErrorKey]);
    
}

- (NSString *)timeStringFromSeconds:(CGFloat)seconds
{
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)seconds / 60, (long)seconds % 60];
}

- (void)dealloc {
    NSLog(@"ZYPlayerViewController dealloc");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
