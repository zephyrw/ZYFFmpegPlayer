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

@end

@implementation ZYPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    [self startPlay];
    
}

- (void)startPlay {
    
    self.player = [ZYPlayer player];
    self.player.view.frame = self.view.bounds;
    [self.view insertSubview:self.player.view atIndex:0];
    
    [self.player replaceVideoWithURL:self.fileURL];
    
}


@end
