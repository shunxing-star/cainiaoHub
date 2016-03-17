//
//  CallAccpectViewController.m
//  MylinphoneDemo022
//
//  Created by 小星星 on 16/1/25.
//  Copyright © 2016年 zsx. All rights reserved.
//

#import "CallAccpectViewController.h"
#import "CallViewController.h"


@interface CallAccpectViewController ()

@property (nonatomic,strong) UIButton *accptBtn;
@property (nonatomic,strong) UIButton *disAccpectBtn;
@property (nonatomic,strong) UIButton *avdioBtn;
@property (nonatomic,strong) UIView *GRbackgView;
@end

@implementation CallAccpectViewController


-(void)viewWillAppear:(BOOL)animated
{
   
}



- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [UIColor whiteColor];
    _accptBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _accptBtn.frame = CGRectMake(50, 100, 80, 40);
    [_accptBtn setTitle:@"接听" forState:UIControlStateNormal];
    [_accptBtn addTarget:self action:@selector(ClickBtn:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_accptBtn];
    
    _disAccpectBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _disAccpectBtn.frame = CGRectMake(50, 160, 80, 40);
    [_disAccpectBtn setTitle:@"拒绝" forState:UIControlStateNormal];
    [_disAccpectBtn addTarget:self action:@selector(ClickBtn:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_disAccpectBtn];
    
//    _avdioBtn = [UIButton buttonWithType:UIButtonTypeSystem];
//    _avdioBtn.frame = CGRectMake(50, 220, 80, 40);
//    [_avdioBtn setTitle:@"开启视屏" forState:UIControlStateNormal];
//    [_avdioBtn addTarget:self action:@selector(ClickBtn:) forControlEvents:UIControlEventTouchUpInside];
//    [self.view addSubview:_avdioBtn];
    
}

-(void)setCall:(LinphoneCall *)call
{
    _call = call;
}

-(void)ClickBtn:(UIButton *)btn
{
    if (btn == _accptBtn) {
        [[LinphoneManager instance] acceptCall:_call];
      
    }
    else if (btn == _disAccpectBtn)
    {
        linphone_core_terminate_call([LinphoneManager getLc], _call);
       
    }
}




- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}




@end
