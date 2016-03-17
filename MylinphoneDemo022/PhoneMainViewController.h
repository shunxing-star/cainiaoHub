//
//  PhoneMainViewController.h
//  MylinphoneDemo022
//
//  Created by 小星星 on 16/1/27.
//  Copyright © 2016年 zsx. All rights reserved.
//

#import <UIKit/UIKit.h>


typedef void (^ActionSheetBlock)(NSInteger);

@interface PhoneMainViewController : UIViewController
{
    BOOL videoShown;
    VideoZoomHandler* videoZoomHandler;
}
@property (strong,nonatomic) CallViewController *callControl;
@property (strong,nonatomic) CallAccpectViewController *callAccpectControl;
@property (strong,nonatomic) GoOutCallViewController *goOutCallControl;
@property (strong,nonatomic) InCallViewController *inCallControl;
@property (strong,nonatomic) VidoCallViewController *vidoCallControl;

//用一个属性来接收block表达式
@property (nonatomic,copy) ActionSheetBlock block1;
//初始化
-(instancetype)initWithCallView:(CallViewController *)CallView
                  andInCallView:(InCallViewController *)InCallView
               andGoOutCallView:(GoOutCallViewController *)GoOutCallView
             andCallAccpectView:(CallAccpectViewController *)CallAccpectView
                andVidoCallView:(VidoCallViewController *)VidoCallView ;


@end
