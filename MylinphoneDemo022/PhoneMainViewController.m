//
//  PhoneMainViewController.m
//  MylinphoneDemo022
//
//  Created by 小星星 on 16/1/27.
//  Copyright © 2016年 zsx. All rights reserved.
//

#import "PhoneMainViewController.h"

@interface PhoneMainViewController ()<UIActionSheetDelegate>

@property (nonatomic,copy) NSString *nameStr;

@end

@implementation PhoneMainViewController

-(void)viewWillAppear:(BOOL)animated
{
//收到信息变化
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(callUpdate:)
                                                 name:kLinphoneCallUpdate
                                               object:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(instancetype)initWithCallView:(CallViewController *)CallView andInCallView:(InCallViewController *)InCallView andGoOutCallView:(GoOutCallViewController *)GoOutCallView andCallAccpectView:(CallAccpectViewController *)CallAccpectView andVidoCallView:(VidoCallViewController *)VidoCallView
{
    if(self){
        self.callControl = CallView;
        self.inCallControl = InCallView;
        self.goOutCallControl = GoOutCallView;
        self.callAccpectControl = CallAccpectView;
        self.vidoCallControl = VidoCallView;
        
        
        self.callControl.view.hidden = NO;
        self.inCallControl.view.hidden = YES;
        self.goOutCallControl.view.hidden = YES;
        self.callAccpectControl.view.hidden = YES;
        self.vidoCallControl.view.hidden = YES;
        
        [self.view addSubview:self.callControl.view];
        [self.view addSubview:self.inCallControl.view];
        [self.view addSubview:self.goOutCallControl.view];
        [self.view addSubview:self.callAccpectControl.view];
        [self.view addSubview:self.vidoCallControl.view];
    }
    return self;
}

//第三方
- (void)callUpdate:(NSNotification*)notif {
    LinphoneCall *call = [[notif.userInfo objectForKey: @"call"] pointerValue];
    LinphoneCallState state = [[notif.userInfo objectForKey: @"state"] intValue];
    
    //来电
    if (state == LinphoneCallIncomingReceived)
    {
        _callControl.view.hidden = YES;
        _inCallControl.view.hidden = YES;
        _goOutCallControl.view.hidden = YES;
        _vidoCallControl.view.hidden = YES;
        _callAccpectControl.view.hidden = NO;
        _callAccpectControl.call = call;
        
        //获得来电的名字是谁
        LinphoneAddress* addr = linphone_call_get_remote_address(call);
         if (addr != NULL)
         {
             char * lAddress = linphone_address_as_string_uri_only(addr);
             NSString *str = [NSString stringWithUTF8String:lAddress];
             NSLog(@"%@",str);
         }
    }
    //开始呼出
    else if (state == LinphoneCallOutgoingInit)
    {
        _callControl.view.hidden = YES;
        _inCallControl.view.hidden = YES;
        _callAccpectControl.view.hidden = YES;
        _vidoCallControl.view.hidden = YES;
        _goOutCallControl.view.hidden = NO;
        
        _goOutCallControl.call = call;
        
    }
    
    //检查摄像头带宽可否使用
    else if (state == LinphoneCallStreamsRunning)
    {
        
    }
    //正在处理呼出
    else if (state == LinphoneCallOutgoingProgress)
    {
        _callControl.view.hidden = YES;
        _inCallControl.view.hidden = YES;
        _callAccpectControl.view.hidden = YES;
        _vidoCallControl.view.hidden = YES;
        _goOutCallControl.view.hidden = NO;
        
        _goOutCallControl.call = call;
    }
    //呼出正在响铃
    else if (state == LinphoneCallOutgoingRinging)
    {
        _callControl.view.hidden = YES;
        _inCallControl.view.hidden = YES;
        _callAccpectControl.view.hidden = YES;
        _vidoCallControl.view.hidden = YES;
        _goOutCallControl.view.hidden = NO;
        
        _goOutCallControl.call = call;
    }
    //接通
    else if (state == LinphoneCallConnected)
    {
        _callControl.view.hidden = YES;
        _inCallControl.view.hidden = NO;
        _goOutCallControl.view.hidden = YES;
        _callAccpectControl.view.hidden = YES;
        _vidoCallControl.view.hidden = YES;
        
        _inCallControl.call = call;
    }
    //配置更新，远程申请视频开启
    else if (state == LinphoneCallUpdatedByRemote)
    {
        _callControl.view.hidden = YES;
        _inCallControl.view.hidden = NO;
        _goOutCallControl.view.hidden = YES;
        _callAccpectControl.view.hidden = YES;
        _vidoCallControl.view.hidden = YES;
        
        _vidoCallControl.call = call;
        LinphoneCore *lc              = [LinphoneManager getLc];
        const LinphoneCallParams* current = linphone_call_get_current_params(call);
        const LinphoneCallParams* remote = linphone_call_get_remote_params(call);
        
     
        /* remote wants to add video */
        if (linphone_core_video_enabled(lc) && !linphone_call_params_video_enabled(current) &&
            linphone_call_params_video_enabled(remote) &&
            !linphone_core_get_video_policy(lc)->automatically_accept) {
            linphone_core_defer_call_update(lc, call);
            [self displayAskToEnableVideoCall:call];
        }
        
    }
    //本地开启视频
    else if (state == LinphoneCallUpdating)
    {
        _callControl.view.hidden = YES;
        _inCallControl.view.hidden = YES;
        _goOutCallControl.view.hidden = YES;
        _callAccpectControl.view.hidden = YES;
        _vidoCallControl.view.hidden = NO;
        
        
        LinphoneCallParams* paramsCopy = linphone_call_params_copy(linphone_call_get_current_params(call));
        linphone_call_params_enable_video(paramsCopy, TRUE);
        linphone_core_accept_call_update([LinphoneManager getLc], call, paramsCopy);
        linphone_call_params_destroy(paramsCopy);
      
        //check video
        //开启摄像头
        if (linphone_call_params_video_enabled(linphone_call_get_current_params(call))) {
            
            [self displayVideoCall:TRUE];
        }
        
    }
    //远程结束
    else if (state == LinphoneCallPausedByRemote)
    {
        _callControl.view.hidden = NO;
        _inCallControl.view.hidden = YES;
        _goOutCallControl.view.hidden = YES;
        _callAccpectControl.view.hidden = YES;
        _vidoCallControl.view.hidden = YES;
    }
    //结束
    else if (state == LinphoneCallEnd)
    {
        _callControl.view.hidden = NO;
        _inCallControl.view.hidden = YES;
        _goOutCallControl.view.hidden = YES;
        _callAccpectControl.view.hidden = YES;
        _vidoCallControl.view.hidden = YES;
    }

    
}
//开启摄像头
- (void)displayVideoCall:(BOOL)animated {
    [self enableVideoDisplay:animated];
}

- (void)enableVideoDisplay:(BOOL)animation {
    if(videoShown && animation)
        return;
    
    videoShown = true;
    
    [videoZoomHandler resetZoom];
    
    if(animation) {
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:1.0];
    }
    
    _inCallControl.view.hidden = YES;
    _vidoCallControl.view.hidden = NO;
    
//    [callTableView setAlpha:0.0];
//    
//    UIEdgeInsets insets = {33, 0, 25, 0};
//    [callTableView setContentInset:insets];
//    [callTableView setScrollIndicatorInsets:insets];
//    [callTableController minimizeAll];
    
    if(animation) {
        [UIView commitAnimations];
    }
    
    if(linphone_core_self_view_enabled([LinphoneManager getLc])) {
        [_vidoCallControl.myView setHidden:FALSE];
    } else {
        [_vidoCallControl.myView setHidden:TRUE];
    }
    
    if ([LinphoneManager instance].frontCamId != nil) {
        // only show camera switch button if we have more than 1 camera
        [_vidoCallControl.caneraSwitch setHidden:FALSE];
    }
  
    
#ifdef TEST_VIDEO_VIEW_CHANGE
    [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(_debugChangeVideoView) userInfo:nil repeats:YES];
#endif
    // [self batteryLevelChanged:nil];
    
    [_vidoCallControl.activ startAnimating];
    
    LinphoneCall *call = linphone_core_get_current_call([LinphoneManager getLc]);
    //linphone_call_params_get_used_video_codec return 0 if no video stream enabled
    if (call != NULL && linphone_call_params_get_used_video_codec(linphone_call_get_current_params(call))) {
//        linphone_call_set_next_video_frame_decoded_callback(call, hideSpinner, self);
    }
}
- (void)_debugChangeVideoView {
    static bool normalView = false;
    if (normalView) {
        linphone_core_set_native_video_window_id([LinphoneManager getLc], (unsigned long)_vidoCallControl.otherView);
    } else {
        linphone_core_set_native_video_window_id([LinphoneManager getLc], (unsigned long)_vidoCallControl.myView);
    }
    normalView = !normalView;
}

//显示是否接受视频的提示框
- (void)displayAskToEnableVideoCall:(LinphoneCall*) call {
    
    if (linphone_core_get_video_policy([LinphoneManager getLc])->automatically_accept)
        return;
    
    const char* lUserNameChars = linphone_address_get_username(linphone_call_get_remote_address(call));
    NSString* lUserName = lUserNameChars?[[NSString alloc] initWithUTF8String:lUserNameChars]:NSLocalizedString(@"Unknown",nil);
    const char* lDisplayNameChars =  linphone_address_get_display_name(linphone_call_get_remote_address(call));
    NSString* lDisplayName = lDisplayNameChars?[[NSString alloc] initWithUTF8String:lDisplayNameChars]:@"";
    NSString* title = [NSString stringWithFormat : NSLocalizedString(@"'%@' would like to enable video",nil), ([lDisplayName length] > 0)?lDisplayName:lUserName];
    
    
    UIActionSheet *actionSheet = [[UIActionSheet alloc]initWithTitle:title delegate:self cancelButtonTitle:@"拒绝" destructiveButtonTitle:@"接受" otherButtonTitles:nil];
    NSTimer *timer1 = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(dismissVideoActionSheet:) userInfo:actionSheet repeats:NO];
    
    __block PhoneMainViewController *controller = self;
    self.block1 = ^(NSInteger index)
    {
        if (index == 0) {
            LinphoneCallParams* paramsCopy = linphone_call_params_copy(linphone_call_get_current_params(call));
            linphone_call_params_enable_video(paramsCopy, TRUE);
            linphone_core_accept_call_update([LinphoneManager getLc], call, paramsCopy);
            linphone_call_params_destroy(paramsCopy);
            [timer1 invalidate];
            
           controller.inCallControl.view.hidden = YES;
           controller.vidoCallControl.view.hidden = NO;
            //check video
            //开启摄像头
            if (linphone_call_params_video_enabled(linphone_call_get_current_params(call))) {
                
                [controller displayVideoCall:TRUE];
            }
        }
        else
        {
            LinphoneCallParams* paramsCopy = linphone_call_params_copy(linphone_call_get_current_params(call));
            linphone_core_accept_call_update([LinphoneManager getLc], call, paramsCopy);
            linphone_call_params_destroy(paramsCopy);
            [timer1 invalidate];
        }
    };
    
    [actionSheet showInView:self.view];
}
-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    self.block1(buttonIndex);
}
- (void)dismissVideoActionSheet:(NSTimer*)timer {
    UIActionSheet *sheet = (UIActionSheet *)timer.userInfo;
    
    [sheet dismissWithClickedButtonIndex:sheet.cancelButtonIndex animated:TRUE];
}


-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


@end
