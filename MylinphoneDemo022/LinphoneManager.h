//
//  LinphoneManager.h
//  MylinphoneDemo022
//
//  Created by 小星星 on 16/1/22.
//  Copyright © 2016年 zsx. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "mediastreamer2/mscommon.h"
#import <UIKit/UILocalNotification.h>
#import <UIKit/UIApplication.h>
#import "FastAddressBook.h"
#import <CoreTelephony/CTCallCenter.h>
#import <SystemConfiguration/SCNetworkReachability.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>

extern NSString *const kLinphoneCoreUpdate;
extern NSString *const kLinphoneDisplayStatusUpdate;
extern NSString *const kLinphoneTextReceived;
extern NSString *const kLinphoneTextComposeEvent;
extern NSString *const kLinphoneCallUpdate;
extern NSString *const kLinphoneRegistrationUpdate;
extern NSString *const kLinphoneMainViewChange;
extern NSString *const kLinphoneAddressBookUpdate;
extern NSString *const kLinphoneLogsUpdate;
extern NSString *const kLinphoneSettingsUpdate;
extern NSString *const kLinphoneBluetoothAvailabilityUpdate;
extern NSString *const kLinphoneConfiguringStateUpdate;
extern NSString *const kLinphoneGlobalStateUpdate;
extern NSString *const kLinphoneNotifyReceived;

typedef enum _NetworkType {
    network_none = 0,
    network_2g,
    network_3g,
    network_4g,
    network_lte,
    network_wifi
} NetworkType;


typedef struct _CallContext {
    LinphoneCall* call;
    bool_t cameraIsEnabled;
} CallContext;

@interface LinphoneCallAppData :NSObject {
@public
    bool_t batteryWarningShown;
    UILocalNotification *notification;
    NSMutableDictionary *userInfos;
    bool_t videoRequested; /*set when user has requested for video*/
    NSTimer* timer;
};
@end

@interface LinphoneManager : NSObject
{
    
@protected
    SCNetworkReachabilityRef proxyReachability;
    
@private
    NSMutableArray*  pushCallIDs;
    UIBackgroundTaskIdentifier incallBgTask;
    UIBackgroundTaskIdentifier pausedCallBgTask;
    CTCallCenter* mCallCenter;
    NSTimer* mIterateTimer;
    //后台
    NSDate *mLastKeepAliveDate;
    
@public
    CallContext currentCallContextBeforeGoingBackground;
}

- (void)call:(NSString *)address displayName:(NSString*)displayName transfer:(BOOL)transfer;
- (void)acceptCall:(LinphoneCall *)call;
- (void)lpConfigSetBool:(BOOL)value forKey:(NSString*)key;
+ (NSString*)documentFile:(NSString*)file;
- (void)configurePushTokenForProxyConfig: (LinphoneProxyConfig*)cfg;
- (bool)allowSpeaker;
+ (LinphoneCore*) getLc;
+ (LinphoneManager*)instance;
- (void)startLibLinphone;
- (void)refreshRegisters;
- (NSString*)lpConfigStringForKey:(NSString*)key withDefault:(NSString*)value;
- (void)setupNetworkReachabilityCallback;
//退到后台
- (BOOL)enterBackgroundMode;
- (void)cancelLocalNotifTimerForCallId:(NSString*)callid;
- (BOOL)lpConfigBoolForKey:(NSString*)key;
- (void)acceptCallForCallId:(NSString*)callid;
- (BOOL)resignActive;
- (void)becomeActive;

@property (readonly) BOOL isTesting;
@property (nonatomic, retain) NSData *pushNotificationToken;
@property (readonly) BOOL wasRemoteProvisioned;
@property (nonatomic, assign) BOOL speakerEnabled;
@property (readonly) FastAddressBook* fastAddressBook;
@property (readonly) NSString* contactSipField;
@property (copy) void (^silentPushCompletion)(UIBackgroundFetchResult);
@property (readonly) LpConfig *configDb;
@property (readonly) NetworkType network;
@property (readonly) const char*  frontCamId;
@property (readonly) const char*  backCamId;

@end
