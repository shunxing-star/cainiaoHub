//
//  AppDelegate.m
//  MylinphoneDemo022
//
//  Created by 小星星 on 16/1/22.
//  Copyright © 2016年 zsx. All rights reserved.
//

#import "AppDelegate.h"
#import <UIKit/UIApplication.h>
@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    UIApplication* app= [UIApplication sharedApplication];
    UIApplicationState state = app.applicationState;
    
    LinphoneManager* instance = [LinphoneManager instance];
    
    if( !instance.isTesting ){
        if( [app respondsToSelector:@selector(registerUserNotificationSettings:)] ){
            /* iOS8 notifications can be actioned! Awesome: */
            UIUserNotificationType notifTypes = UIUserNotificationTypeBadge|UIUserNotificationTypeSound|UIUserNotificationTypeAlert;
            
            NSSet* categories = [NSSet setWithObjects:[self getCallNotificationCategory], [self getMessageNotificationCategory], nil];
            UIUserNotificationSettings* userSettings = [UIUserNotificationSettings settingsForTypes:notifTypes categories:categories];
            [app registerUserNotificationSettings:userSettings];
            [app registerForRemoteNotifications];
        } else {
            NSUInteger notifTypes = UIRemoteNotificationTypeAlert|UIRemoteNotificationTypeSound|UIRemoteNotificationTypeBadge|UIRemoteNotificationTypeNewsstandContentAvailability;
            [app registerForRemoteNotificationTypes:notifTypes];
        }
    } else {
        NSLog(@"No remote push for testing");
    }
    
    
    if (state == UIApplicationStateBackground)
    {
    }
    [[LinphoneManager instance]	startLibLinphone];
    // initialize UI
    [self.window makeKeyAndVisible];
    
    NSDictionary *remoteNotif =[launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if (remoteNotif){
        [LinphoneLogger log:LinphoneLoggerLog format:@"PushNotification from launch received."];
    }
    return YES;
}

- (UIUserNotificationCategory*)getMessageNotificationCategory {
    
    UIMutableUserNotificationAction* reply = [[UIMutableUserNotificationAction alloc] init];
    reply.identifier = @"reply";
    reply.title = NSLocalizedString(@"Reply", nil);
    reply.activationMode = UIUserNotificationActivationModeForeground;
    reply.destructive = NO;
    reply.authenticationRequired = YES;
    
    UIMutableUserNotificationAction* mark_read = [[UIMutableUserNotificationAction alloc] init];
    mark_read.identifier = @"mark_read";
    mark_read.title = NSLocalizedString(@"Mark Read", nil);
    mark_read.activationMode = UIUserNotificationActivationModeBackground;
    mark_read.destructive = NO;
    mark_read.authenticationRequired = NO;
    
    NSArray* localRingActions = @[mark_read, reply];
    
    UIMutableUserNotificationCategory* localRingNotifAction = [[UIMutableUserNotificationCategory alloc] init];
    localRingNotifAction.identifier = @"incoming_msg";
    [localRingNotifAction setActions:localRingActions forContext:UIUserNotificationActionContextDefault];
    [localRingNotifAction setActions:localRingActions forContext:UIUserNotificationActionContextMinimal];
    
    return localRingNotifAction;
}


- (UIUserNotificationCategory*)getCallNotificationCategory {
    UIMutableUserNotificationAction* answer = [[UIMutableUserNotificationAction alloc] init];
    answer.identifier = @"answer";
    answer.title = NSLocalizedString(@"Answer", nil);
    answer.activationMode = UIUserNotificationActivationModeForeground;
    answer.destructive = NO;
    answer.authenticationRequired = YES;
    
    UIMutableUserNotificationAction* decline = [[UIMutableUserNotificationAction alloc] init] ;
    decline.identifier = @"decline";
    decline.title = NSLocalizedString(@"Decline", nil);
    decline.activationMode = UIUserNotificationActivationModeBackground;
    decline.destructive = YES;
    decline.authenticationRequired = NO;
    
    
    NSArray* localRingActions = @[decline, answer];
    
    UIMutableUserNotificationCategory* localRingNotifAction = [[UIMutableUserNotificationCategory alloc] init];
    localRingNotifAction.identifier = @"incoming_call";
    [localRingNotifAction setActions:localRingActions forContext:UIUserNotificationActionContextDefault];
    [localRingNotifAction setActions:localRingActions forContext:UIUserNotificationActionContextMinimal];
    
    return localRingNotifAction;
}


- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken {
    Linphone_log(@"%@ : %@", NSStringFromSelector(_cmd), deviceToken);
    [[LinphoneManager instance] setPushNotificationToken:deviceToken];
}

- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error {
    Linphone_log(@"%@ : %@", NSStringFromSelector(_cmd), [error localizedDescription]);
    [[LinphoneManager instance] setPushNotificationToken:nil];
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    Linphone_log(@"%@", NSStringFromSelector(_cmd));
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    Linphone_log(@"%@", NSStringFromSelector(_cmd));
    LinphoneCore* lc = [LinphoneManager getLc];
    LinphoneCall* call = linphone_core_get_current_call(lc);
    
    if (call){
        /* save call context */
        LinphoneManager* instance = [LinphoneManager instance];
        instance->currentCallContextBeforeGoingBackground.call = call;
        instance->currentCallContextBeforeGoingBackground.cameraIsEnabled = linphone_call_camera_enabled(call);
        
        const LinphoneCallParams* params = linphone_call_get_current_params(call);
        if (linphone_call_params_video_enabled(params)) {
            linphone_call_enable_camera(call, false);
        }
    }
    
    if (![[LinphoneManager instance] resignActive]) {
        
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    Linphone_log(@"%@", NSStringFromSelector(_cmd));
   
    [[LinphoneManager instance] enterBackgroundMode];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    Linphone_log(@"%@", NSStringFromSelector(_cmd));
    
    if( startedInBackground ){
        startedInBackground = FALSE;
//        [[PhoneMainView instance] startUp];
//        [[PhoneMainView instance] updateStatusBar:nil];
    }
    LinphoneManager* instance = [LinphoneManager instance];
    
    [instance becomeActive];
    
    LinphoneCore* lc = [LinphoneManager getLc];
    LinphoneCall* call = linphone_core_get_current_call(lc);
    
    if (call){
        if (call == instance->currentCallContextBeforeGoingBackground.call) {
            const LinphoneCallParams* params = linphone_call_get_current_params(call);
            if (linphone_call_params_video_enabled(params)) {
                linphone_call_enable_camera(
                                            call,
                                            instance->currentCallContextBeforeGoingBackground.cameraIsEnabled);
            }
            instance->currentCallContextBeforeGoingBackground.call = 0;
        } else if ( linphone_call_get_state(call) == LinphoneCallIncomingReceived ) {
//            [[PhoneMainView  instance ] displayIncomingCall:call];
            // in this case, the ringing sound comes from the notification.
            // To stop it we have to do the iOS7 ring fix...
            [self fixRing];
        }
    }
}



- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


// this method is implemented for iOS7. It is invoked when receiving a push notification for a call and it has "content-available" in the aps section.
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    Linphone_log(@"%@ : %@", NSStringFromSelector(_cmd), userInfo);
    LinphoneManager* lm = [LinphoneManager instance];
    
    // save the completion handler for later execution.
    // 2 outcomes:
    // - if a new call/message is received, the completion handler will be called with "NEWDATA"
    // - if nothing happens for 15 seconds, the completion handler will be called with "NODATA"
    lm.silentPushCompletion = completionHandler;
    
    LinphoneCore *lc=[LinphoneManager getLc];
    // If no call is yet received at this time, then force Linphone to drop the current socket and make new one to register, so that we get
    // a better chance to receive the INVITE.
    if (linphone_core_get_calls(lc)==NULL){
        linphone_core_set_network_reachable(lc, FALSE);
        [lm refreshRegisters];
    }
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    Linphone_log(@"%@ - state = %ld", NSStringFromSelector(_cmd), (long)application.applicationState);
    
    [self fixRing];
    
    if([notification.userInfo objectForKey:@"callId"] != nil) {
        BOOL auto_answer = TRUE;
        
        // some local notifications have an internal timer to relaunch themselves at specified intervals
        if( [[notification.userInfo objectForKey:@"timer"] intValue] == 1 ){
            [[LinphoneManager instance] cancelLocalNotifTimerForCallId:[notification.userInfo objectForKey:@"callId"]];
            auto_answer = [[LinphoneManager instance] lpConfigBoolForKey:@"autoanswer_notif_preference"];
        }
        if(auto_answer)
        {
            [[LinphoneManager instance] acceptCallForCallId:[notification.userInfo objectForKey:@"callId"]];
        }
    } else if([notification.userInfo objectForKey:@"from"] != nil) {
        NSString *remoteContact = (NSString*)[notification.userInfo objectForKey:@"from"];
        // Go to ChatRoom view
//        [[PhoneMainView instance] changeCurrentView:[ChatViewController compositeViewDescription]];
//        LinphoneChatRoom*room = [self findChatRoomForContact:remoteContact];
//        ChatRoomViewController *controller = DYNAMIC_CAST([[PhoneMainView instance] changeCurrentView:[ChatRoomViewController compositeViewDescription] push:TRUE], ChatRoomViewController);
//        if(controller != nil && room != nil) {
//            [controller setChatRoom:room];
//        }
    } else if([notification.userInfo objectForKey:@"callLog"] != nil) {
        NSString *callLog = (NSString*)[notification.userInfo objectForKey:@"callLog"];
        // Go to HistoryDetails view
//        [[PhoneMainView instance] changeCurrentView:[HistoryViewController compositeViewDescription]];
//        HistoryDetailsViewController *controller = DYNAMIC_CAST([[PhoneMainView instance] changeCurrentView:[HistoryDetailsViewController compositeViewDescription] push:TRUE], HistoryDetailsViewController);
//        if(controller != nil) {
//            [controller setCallLogId:callLog];
//        }
    }
}

- (void)fixRing{
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7) {
        // iOS7 fix for notification sound not stopping.
        // see http://stackoverflow.com/questions/19124882/stopping-ios-7-remote-notification-sound
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber: 1];
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber: 0];
    }
}



@end
