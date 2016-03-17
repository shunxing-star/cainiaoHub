//
//  VidoCallViewController.m
//  MylinphoneDemo022
//
//  Created by 小星星 on 16/1/27.
//  Copyright © 2016年 zsx. All rights reserved.
//

#import "VidoCallViewController.h"

@interface VidoCallViewController ()

@end

@implementation VidoCallViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    //对方的视频
    self.otherView = [[UIView alloc] initWithFrame:CGRectMake(0, 64, self.view.frame.size.width, self.view.frame.size.height)];
    _otherView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:_otherView];
    
    //前后摄像头的选择
    _caneraSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(50, 70, 20, 20)];
    [_caneraSwitch addTarget:self action:@selector(switchValueChange:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_caneraSwitch];
    
    //显示自己的视屏
    _myView = [[UIView alloc] initWithFrame:CGRectMake(self.view.frame.size.width - 150, self.view.frame.size.height - 250, 150, 230)];
    _myView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:_myView];
    
    //等待视图
    
    _activ = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _activ.center = CGPointMake(self.view.frame.size.width / 2.0, 1.0* self.view.frame.size.height/2.0);
    [self.view addSubview:_activ];
    
    
    UIButton *butn = [UIButton buttonWithType:UIButtonTypeSystem];
    butn.frame = CGRectMake(50, self.view.frame.size.height - 60, 60, 20);
    butn.backgroundColor = [UIColor whiteColor];
    [butn setTitle:@"拒绝" forState:UIControlStateNormal];
    [butn addTarget:self action:@selector(ClickBtn:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:butn];
    
    
    linphone_core_set_native_video_window_id([LinphoneManager getLc], (unsigned long)_otherView);
    linphone_core_set_native_preview_window_id([LinphoneManager getLc], (unsigned long)_myView);
}

-(void)setCall:(LinphoneCall *)call
{
    _call = call;
}

-(void)switchValueChange:(UISwitch *)swit
{
    const char *currentCamId = (char*)linphone_core_get_video_device([LinphoneManager getLc]);
    const char **cameras=linphone_core_get_video_devices([LinphoneManager getLc]);
    const char *newCamId=NULL;
    int i;
    
    for (i=0;cameras[i]!=NULL;++i){
        if (strcmp(cameras[i],"StaticImage: Static picture")==0) continue;
        if (strcmp(cameras[i],currentCamId)!=0){
            newCamId=cameras[i];
            break;
        }
    }
    if (newCamId){
        [LinphoneLogger logc:LinphoneLoggerLog format:"Switching from [%s] to [%s]", currentCamId, newCamId];
        linphone_core_set_video_device([LinphoneManager getLc], newCamId);
        LinphoneCall *call = linphone_core_get_current_call([LinphoneManager getLc]);
        if(call != NULL) {
            linphone_core_update_call([LinphoneManager getLc], call, NULL);
        }
        
    }
}

-(void)ClickBtn:(UIButton *)btn
{
    linphone_core_terminate_call([LinphoneManager getLc], _call);
}


@end
