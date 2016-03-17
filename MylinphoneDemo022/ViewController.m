//
//  ViewController.m
//  MylinphoneDemo022
//
//  Created by 小星星 on 16/1/22.
//  Copyright © 2016年 zsx. All rights reserved.
//

#import "ViewController.h"
#import "CallViewController.h"
#import "PhoneMainViewController.h"
#import "CallAccpectViewController.h"
#import "GoOutCallViewController.h"
#import "InCallViewController.h"
#import "VidoCallViewController.h"

@interface ViewController ()
@property (strong, nonatomic) IBOutlet UITextField *nameText;

@property (strong, nonatomic) IBOutlet UITextField *passText;

@property (strong, nonatomic) IBOutlet UITextField *ipText;
@property (strong, nonatomic) IBOutlet UIButton *loginBtn;

@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
//    _nameText.text = @"zsx123";
//    _passText.text = @"123456";
//    _ipText.text = @"sip.linphone.org";

        _nameText.text = @"zsxdemo1";
        _passText.text = @"123456";
        _ipText.text = @"sip.linphone.org";
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)clickBtn:(UIButton *)sender {
    
   BOOL sucess = [self addProxyConfig:_nameText.text password:_passText.text domain:_ipText.text withTransport:@"UDP"];
    
    if (sucess) {
        CallViewController *call = [[CallViewController alloc] init];
        CallAccpectViewController *callAccpet = [[CallAccpectViewController alloc] init];
        GoOutCallViewController *goOutCall = [[GoOutCallViewController alloc] init];
        InCallViewController *inCall = [[InCallViewController alloc] init];
        VidoCallViewController *vidoCall = [[VidoCallViewController alloc] init];
        PhoneMainViewController *phoneMain = [[PhoneMainViewController alloc] initWithCallView:call andInCallView:inCall andGoOutCallView:goOutCall andCallAccpectView:callAccpet andVidoCallView:vidoCall];
        [self presentViewController:phoneMain animated:YES completion:^{
            //
        }];
    }
}

- (BOOL)addProxyConfig:(NSString*)username password:(NSString*)password domain:(NSString*)domain withTransport:(NSString*)transport {
    
    LinphoneCore* lc = [LinphoneManager getLc];
    LinphoneProxyConfig* proxyCfg = linphone_core_create_proxy_config(lc);
    NSString* server_address = domain;
    
    char normalizedUserName[256];
    linphone_proxy_config_normalize_number(proxyCfg, [username cStringUsingEncoding:[NSString defaultCStringEncoding]], normalizedUserName, sizeof(normalizedUserName));
    
    const char* identity = linphone_proxy_config_get_identity(proxyCfg);
    if( !identity || !*identity ) identity = "sip:user@example.com";
    
    // 修改部分 1
    //    const char *identity = [@"sip:User name@IP:端口" cStringUsingEncoding:NSUTF8StringEncoding];
    //
    LinphoneAddress* linphoneAddress = linphone_address_new(identity);
    linphone_address_set_username(linphoneAddress, normalizedUserName);
    
    if( domain && [domain length] != 0) {
        if( transport != nil ){
            server_address = [NSString stringWithFormat:@"%@;transport=%@", server_address, [transport lowercaseString]];
            
            // 修改部分 2
            //            server_address = [NSString stringWithFormat:@"%@:%@;transport=%@", server_address, @"端口", [transport lowercaseString]];
            //
        }
        // when the domain is specified (for external login), take it as the server address
        linphone_proxy_config_set_server_addr(proxyCfg, [server_address UTF8String]);
        linphone_address_set_domain(linphoneAddress, [domain UTF8String]);
    }
    
    char* extractedAddres = linphone_address_as_string_uri_only(linphoneAddress);
    
    //测试
      NSString *str = [NSString stringWithFormat:@"sip:%@@%@",username,domain];
    extractedAddres = [str UTF8String];
    
    LinphoneAddress* parsedAddress = linphone_address_new(extractedAddres);
//    ms_free(extractedAddres);
    
    if( parsedAddress == NULL || !linphone_address_is_sip(parsedAddress) ){
        if( parsedAddress ) linphone_address_destroy(parsedAddress);
        UIAlertView* errorView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Check error(s)",nil)
                                                            message:NSLocalizedString(@"Please enter a valid username", nil)
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"Continue",nil)
                                                  otherButtonTitles:nil,nil];
        [errorView show];
        return FALSE;
    }
    
    char *c_parsedAddress = linphone_address_as_string_uri_only(parsedAddress);
    
    linphone_proxy_config_set_identity(proxyCfg, c_parsedAddress);
    
    linphone_address_destroy(parsedAddress);
    ms_free(c_parsedAddress);
    
    LinphoneAuthInfo* info = linphone_auth_info_new([username UTF8String]
                                                    , NULL, [password UTF8String]
                                                    , NULL
                                                    , NULL
                                                    ,linphone_proxy_config_get_domain(proxyCfg));
    
    [self setDefaultSettings:proxyCfg];
    
    [self clearProxyConfig];
    
    linphone_proxy_config_enable_register(proxyCfg, true);
    linphone_core_add_auth_info(lc, info);
    linphone_core_add_proxy_config(lc, proxyCfg);
    linphone_core_set_default_proxy_config(lc, proxyCfg);
    
    return TRUE;
    
}

- (void)clearProxyConfig {
    linphone_core_clear_proxy_config([LinphoneManager getLc]);
    linphone_core_clear_all_auth_info([LinphoneManager getLc]);
}

- (void)setDefaultSettings:(LinphoneProxyConfig*)proxyCfg {
    LinphoneManager* lm = [LinphoneManager instance];
    [lm configurePushTokenForProxyConfig:proxyCfg];
    
}

@end
