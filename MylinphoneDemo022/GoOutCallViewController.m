//
//  GoOutCallViewController.m
//  MylinphoneDemo022
//
//  Created by 小星星 on 16/1/27.
//  Copyright © 2016年 zsx. All rights reserved.
//

#import "GoOutCallViewController.h"

@interface GoOutCallViewController ()

@property (nonatomic,strong) UILabel *nameLabel;
@property (nonatomic,strong) UIButton *deleBtn;
@property (nonatomic,strong) NSTimer *time1;
@property (nonatomic,strong) UILabel *timeLabel;
@end

@implementation GoOutCallViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    UILabel *label1 = [[UILabel alloc] initWithFrame:CGRectMake(100, 65, 200, 30)];
    label1.text = @"呼出中。。。。";
    [self.view addSubview:label1];
    
    _nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(100, 100, 200, 50)];
    _nameLabel.textAlignment = NSTextAlignmentCenter;
    _nameLabel.font = [UIFont systemFontOfSize:25.0];
    [self.view addSubview:_nameLabel];
    
    _timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(150, 180, 200, 30)];
    _timeLabel.textAlignment = NSTextAlignmentCenter;
    _timeLabel.font = [UIFont systemFontOfSize:15.0];
    [self.view addSubview:_timeLabel];
    
    _deleBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _deleBtn.frame = CGRectMake(150, 250, 50, 30);
    _deleBtn.backgroundColor = [UIColor greenColor];
    [_deleBtn setTitle:@"挂断" forState:UIControlStateNormal];
    [_deleBtn addTarget:self action:@selector(CLickBtn:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_deleBtn];
    
    
    //    //添加定时器
        _time1 = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(runSlider) userInfo:nil repeats:NO];
        NSRunLoop * loop = [NSRunLoop currentRunLoop];
        [loop addTimer:_time1 forMode:NSRunLoopCommonModes];
}

-(void)setCall:(LinphoneCall *)call
{
    _call = call;
}

-(void)CLickBtn:(UIButton *)btn
{
    linphone_core_terminate_call([LinphoneManager getLc], _call);
    
}

-(void)runSlider
{
    
}

@end
