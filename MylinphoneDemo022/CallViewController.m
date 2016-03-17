//
//  CallViewController.m
//  MyLinPhoneDemo1
//
//  Created by 小星星 on 16/1/19.
//  Copyright © 2016年 zsx. All rights reserved.
//

#import "CallViewController.h"
#import "CallAccpectViewController.h"

@interface CallViewController ()<UITextFieldDelegate>

@property (nonatomic,strong) UITextField *numberText;
@property (nonatomic,strong) UIButton *callBtn;
@property (nonatomic,strong) UILabel *label1;
@end

@implementation CallViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    
    self.view.backgroundColor = [UIColor brownColor];
    
    self.numberText = [[UITextField alloc] initWithFrame:CGRectMake(20, 100, 150, 30)];
    _numberText.placeholder = @"请输入账号";
    _numberText.delegate = self;
    [self.view addSubview:self.numberText];
    
    
    self.callBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _callBtn.frame = CGRectMake(30, 160, 100, 30);
    [_callBtn setTitle:@"拨打" forState:UIControlStateNormal];
    [_callBtn addTarget:self action:@selector(ClickBtn:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_callBtn];
    
    _label1 = [[UILabel alloc] initWithFrame:CGRectMake(50, 250, 100, 40)];
    _label1.textColor= [UIColor whiteColor];
    _label1.font = [UIFont systemFontOfSize:25.0];
    [self.view addSubview:_label1];
    
}

-(void)ClickBtn:(UIButton *)btn
{
    NSString *address = [_numberText text];
    NSString *displayName = nil;
    
    if( [address length] == 0){
        const MSList* logs = linphone_core_get_call_logs([LinphoneManager getLc]);
        while( logs ){
            LinphoneCallLog* log = logs->data;
            if( linphone_call_log_get_dir(log) == LinphoneCallOutgoing ){
                LinphoneProxyConfig* def_proxy = NULL;
                LinphoneAddress* to = linphone_call_log_get_to(log);
                const char*  domain = linphone_address_get_domain(to);
                char*   bis_address = NULL;
                
                linphone_core_get_default_proxy([LinphoneManager getLc], &def_proxy);
                
                // if the 'to' address is on the default proxy, only present the username
                if( def_proxy ){
                    const char* def_domain = linphone_proxy_config_get_domain(def_proxy);
                    if( def_domain && domain && !strcmp(domain, def_domain) ){
                        bis_address = ms_strdup(linphone_address_get_username(to));
                    }
                }
                
                if( bis_address == NULL ) {
                    bis_address = linphone_address_as_string_uri_only(to);
                }
                
                
                // return after filling the address, let the user confirm the call by pressing again
                return;
            }
            logs = ms_list_next(logs);
        }
    }
    
    if( [address length] > 0){
        ABRecordRef contact = [[[LinphoneManager instance] fastAddressBook] getContact:address];
        if(contact) {
            displayName = [FastAddressBook getContactDisplayName:contact];
        }
        [[LinphoneManager instance] call:address displayName:displayName transfer:FALSE];
    }

}

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self.numberText resignFirstResponder];
    return YES;
}



@end
