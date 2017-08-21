//
//  ViewController.m
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/7/20.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import "ViewController.h"
#import "ZYPlayerViewController.h"

@interface ViewController ()

@property (strong, nonatomic) NSArray *fileNameArr;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.fileNameArr = @[
                         [self pathWithFileName:@"VR"],
                         [self pathWithFileName:@"google-help-vr"],
                         [self pathWithFileName:@"i-see-fire"],
                         ];
    
}

- (NSString *)pathWithFileName:(NSString *)fileName {
    
    return [[NSBundle mainBundle] pathForResource:fileName ofType:@"mp4"];
    
}

#pragma mark - TableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return self.fileNameArr.count;
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *cellIdentifier = @"fileNameCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
    }
    
    cell.textLabel.text = [[self.fileNameArr[indexPath.row] lastPathComponent] componentsSeparatedByString:@"."].firstObject;
    
    return cell;
    
}

#pragma mark - TableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    ZYPlayerViewController *playerContr = [ZYPlayerViewController new];
    playerContr.fileURL = [NSURL fileURLWithPath:self.fileNameArr[indexPath.row]];
    [self.navigationController pushViewController:playerContr animated:YES];
    
}

@end
