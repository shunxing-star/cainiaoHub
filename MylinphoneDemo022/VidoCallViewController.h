//
//  VidoCallViewController.h
//  MylinphoneDemo022
//
//  Created by 小星星 on 16/1/27.
//  Copyright © 2016年 zsx. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface VidoCallViewController : UIViewController


@property (nonatomic,strong) UIView *otherView;
@property (nonatomic,strong) UIView *myView;
@property (nonatomic,strong) UISwitch * caneraSwitch;
@property (nonatomic,strong) UIActivityIndicatorView *activ;
@property (nonatomic,assign) LinphoneCall* call;

@end
