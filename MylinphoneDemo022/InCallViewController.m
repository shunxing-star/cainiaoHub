//
//  InCallViewController.m
//  MylinphoneDemo022
//
//  Created by 小星星 on 16/1/27.
//  Copyright © 2016年 zsx. All rights reserved.
//

#import "InCallViewController.h"

@interface InCallViewController ()

@property (nonatomic,strong) UIButton *endBtn;
@property (nonatomic,strong) UIButton *VideoBtn;

@end

@implementation InCallViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    UILabel *label1 = [[UILabel alloc] initWithFrame:CGRectMake(100, 65, 200, 30)];
    label1.text = @"通话中。。。。";
    [self.view addSubview:label1];
    
    
    _VideoBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _VideoBtn.frame = CGRectMake(150, 200, 50, 30);
    _VideoBtn.backgroundColor = [UIColor yellowColor];
    [_VideoBtn setTitle:@"开启视频" forState:UIControlStateNormal];
    [_VideoBtn addTarget:self action:@selector(CLickBtn:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_VideoBtn];
    
    _endBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _endBtn.frame = CGRectMake(150, 300, 50, 30);
    _endBtn.backgroundColor = [UIColor redColor];
    [_endBtn setTitle:@"挂断" forState:UIControlStateNormal];
    [_endBtn addTarget:self action:@selector(CLickBtn:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_endBtn];
}

-(void)setCall:(LinphoneCall *)call
{
    _call = call;
}


-(void)CLickBtn:(UIButton *)btn
{
    if (btn == _VideoBtn) {
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
        
        LinphoneCore* lc = [LinphoneManager getLc];
        
        if (!linphone_core_video_enabled(lc))
            return;
        LinphoneCall* call = linphone_core_get_current_call([LinphoneManager getLc]);
        if (call) {
            LinphoneCallParams* call_params =  linphone_call_params_copy(linphone_call_get_current_params(call));
            linphone_call_params_enable_video(call_params, TRUE);
            linphone_core_update_call(lc, call, call_params);
            linphone_call_params_destroy(call_params);
        } else {
            [LinphoneLogger logc:LinphoneLoggerWarning format:"Cannot toggle video button, because no current call"];
        }
        
        BOOL enbale = [self onUpdate];
    }
    else if (btn == _endBtn)
    {
        linphone_core_terminate_call([LinphoneManager getLc], _call);
        
    }
}


- (bool)onUpdate {
    bool video_enabled = false;
    
    
    LinphoneCall* currentCall = linphone_core_get_current_call([LinphoneManager getLc]);
    if( linphone_core_video_enabled([LinphoneManager getLc])
       && currentCall
       && !linphone_call_media_in_progress(currentCall)
       && linphone_call_get_state(currentCall) == LinphoneCallStreamsRunning) {
        video_enabled = TRUE;
    }
    
    
    if( video_enabled ){
        video_enabled = linphone_call_params_video_enabled(linphone_call_get_current_params(currentCall));
    }
    
    
    return video_enabled;
}


@end
