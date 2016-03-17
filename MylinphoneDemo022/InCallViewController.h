//
//  InCallViewController.h
//  MylinphoneDemo022
//
//  Created by 小星星 on 16/1/27.
//  Copyright © 2016年 zsx. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VideoZoomHandler.h"

@interface InCallViewController : UIViewController
{
    BOOL videoShown;
    VideoZoomHandler* videoZoomHandler;
    
}
@property (nonatomic,assign) LinphoneCall* call;

@end
