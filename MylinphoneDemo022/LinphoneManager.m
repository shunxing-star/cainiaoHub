//
//  LinphoneManager.m
//  MylinphoneDemo022
//
//  Created by 小星星 on 16/1/22.
//  Copyright © 2016年 zsx. All rights reserved.
//

#import "LinphoneManager.h"
#import <AVFoundation/AVAudioSession.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVAudioPlayer.h>
#import <CoreTelephony/CTCallCenter.h>
#import <AudioToolbox/AudioSession.h>
#include <MacTypes.h>
#import <UIKit/UIDevice.h>


static LinphoneCore* theLinphoneCore = nil;
static LinphoneManager* theLinphoneManager = nil;

const char *const LINPHONERC_APPLICATION_KEY = "app";

NSString *const kLinphoneCoreUpdate = @"LinphoneCoreUpdate";
NSString *const kLinphoneDisplayStatusUpdate = @"LinphoneDisplayStatusUpdate";
NSString *const kLinphoneTextReceived = @"LinphoneTextReceived";
NSString *const kLinphoneTextComposeEvent = @"LinphoneTextComposeStarted";
NSString *const kLinphoneCallUpdate = @"LinphoneCallUpdate";
NSString *const kLinphoneRegistrationUpdate = @"LinphoneRegistrationUpdate";
NSString *const kLinphoneAddressBookUpdate = @"LinphoneAddressBookUpdate";
NSString *const kLinphoneMainViewChange = @"LinphoneMainViewChange";
NSString *const kLinphoneLogsUpdate = @"LinphoneLogsUpdate";
NSString *const kLinphoneSettingsUpdate = @"LinphoneSettingsUpdate";
NSString *const kLinphoneBluetoothAvailabilityUpdate = @"LinphoneBluetoothAvailabilityUpdate";
NSString *const kLinphoneConfiguringStateUpdate = @"LinphoneConfiguringStateUpdate";
NSString *const kLinphoneGlobalStateUpdate = @"LinphoneGlobalStateUpdate";
NSString *const kLinphoneNotifyReceived = @"LinphoneNotifyReceived";




//初始化ilbc
extern void libmsilbc_init(void);
extern void libmsamr_init(void);
extern void libmsx264_init(void);
extern void libmsopenh264_init(void);
extern void libmssilk_init(void);
extern void libmsbcg729_init(void);

#define FRONT_CAM_NAME "AV Capture: com.apple.avfoundation.avcapturedevice.built-in_video:1" /*"AV Capture: Front Camera"*/
#define BACK_CAM_NAME "AV Capture: com.apple.avfoundation.avcapturedevice.built-in_video:0" /*"AV Capture: Back Camera"*/

@implementation LinphoneCallAppData
- (id)init {
    if ((self = [super init])) {
        self->batteryWarningShown = FALSE;
        self->notification = nil;
        self->videoRequested = FALSE;
        self->userInfos = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc {
    [self->userInfos release];
    [super dealloc];
}
@end


@interface LinphoneManager ()
@property (retain, nonatomic) AVAudioPlayer* messagePlayer;
@end

@implementation LinphoneManager

@synthesize frontCamId;
@synthesize backCamId;
@synthesize pushNotificationToken;
@synthesize speakerEnabled;
@synthesize fastAddressBook;
@synthesize silentPushCompletion;
@synthesize configDb;
@synthesize wasRemoteProvisioned;

struct codec_name_pref_table{
    const char *name;
    int rate;
    NSString *prefname;
};

struct codec_name_pref_table codec_pref_table[]={
    { "speex", 8000, @"speex_8k_preference" },
    { "speex", 16000, @"speex_16k_preference" },
    { "silk", 24000, @"silk_24k_preference" },
    { "silk", 16000, @"silk_16k_preference" },
    { "amr", 8000, @"amr_preference" },
    { "gsm", 8000, @"gsm_preference" },
    { "ilbc", 8000, @"ilbc_preference"},
    { "pcmu", 8000, @"pcmu_preference"},
    { "pcma", 8000, @"pcma_preference"},
    { "g722", 8000, @"g722_preference"},
    { "g729", 8000, @"g729_preference"},
    { "mp4v-es", 90000, @"mp4v-es_preference"},
    { "h264", 90000, @"h264_preference"},
    { "vp8", 90000, @"vp8_preference"},
    { "mpeg4-generic", 16000, @"aaceld_16k_preference"},
    { "mpeg4-generic", 22050, @"aaceld_22k_preference"},
    { "mpeg4-generic", 32000, @"aaceld_32k_preference"},
    { "mpeg4-generic", 44100, @"aaceld_44k_preference"},
    { "mpeg4-generic", 48000, @"aaceld_48k_preference"},
    { "opus", 48000, @"opus_preference"},
    { NULL,0,Nil }
};

+ (LinphoneManager*)instance {
    if(theLinphoneManager == nil) {
        theLinphoneManager = [LinphoneManager alloc];
        [theLinphoneManager init];
    }
    return theLinphoneManager;
}
- (void)dealloc {
    [fastAddressBook release];
//    [logs release];
    
//    OSStatus lStatus = AudioSessionRemovePropertyListenerWithUserData(kAudioSessionProperty_AudioRouteChange, audioRouteChangeListenerCallback, self);
//    if (lStatus) {
//        [LinphoneLogger logc:LinphoneLoggerError format:"cannot un register route change handler [%ld]", lStatus];
//    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath:kLinphoneGlobalStateUpdate];
    [[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath:kLinphoneConfiguringStateUpdate];
    
    
//    [photoLibrary release];
    [pushCallIDs release];
    [super dealloc];
}

- (id)init {
    if ((self = [super init])) {
        AudioSessionInitialize(NULL, NULL, NULL, NULL);
        OSStatus lStatus = AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, audioRouteChangeListenerCallback, self);
        if (lStatus) {
            [LinphoneLogger logc:LinphoneLoggerError format:"cannot register route change handler [%ld]",lStatus];
        }
        
        
        NSString *path = [[NSBundle mainBundle] pathForResource:@"msg" ofType:@"wav"];
        self.messagePlayer = [[[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL URLWithString:path] error:nil] autorelease];
        
//        sounds.vibrate = kSystemSoundID_Vibrate;
//        
//        logs = [[NSMutableArray alloc] init];
//        database = NULL;
//        speakerEnabled = FALSE;
//        bluetoothEnabled = FALSE;
//        tunnelMode = FALSE;
//        [self copyDefaultSettings];
        pushCallIDs = [[NSMutableArray alloc] init ];
//        photoLibrary = [[ALAssetsLibrary alloc] init];
        self->_isTesting = [LinphoneManager isRunningTests];
        
        NSString* factoryConfig = [LinphoneManager bundleFile:[LinphoneManager runningOnIpad]?@"linphonerc-factory~ipad":@"linphonerc-factory"];
        NSString *confiFileName = [LinphoneManager documentFile:@".linphonerc"];
        configDb=lp_config_new_with_factory([confiFileName cStringUsingEncoding:[NSString defaultCStringEncoding]] , [factoryConfig cStringUsingEncoding:[NSString defaultCStringEncoding]]);
        
        //set default values for first boot
        if (lp_config_get_string(configDb,LINPHONERC_APPLICATION_KEY,"debugenable_preference",NULL)==NULL){
#ifdef DEBUG
            [self lpConfigSetBool:TRUE forKey:@"debugenable_preference"];
#else
            [self lpConfigSetBool:FALSE forKey:@"debugenable_preference"];
#endif
        }
        
        [self migrateFromUserPrefs];
    }
    return self;
}

//拨打电话
- (void)call:(NSString *)address displayName:(NSString*)displayName transfer:(BOOL)transfer {
    if (!linphone_core_is_network_reachable(theLinphoneCore)) {
        UIAlertView* error = [[UIAlertView alloc]	initWithTitle:NSLocalizedString(@"Network Error",nil)
                                                        message:NSLocalizedString(@"There is no network connection available, enable WIFI or WWAN prior to place a call",nil)
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"Continue",nil)
                                              otherButtonTitles:nil];
        [error show];
        [error release];
        return;
    }
    
    CTCallCenter* callCenter = [[CTCallCenter alloc] init];
    if ([callCenter currentCalls]!=nil) {
        [LinphoneLogger logc:LinphoneLoggerError format:"GSM call in progress, cancelling outgoing SIP call request"];
        UIAlertView* error = [[UIAlertView alloc]	initWithTitle:NSLocalizedString(@"Cannot make call",nil)
                                                        message:NSLocalizedString(@"Please terminate GSM call",nil)
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"Continue",nil)
                                              otherButtonTitles:nil];
        [error show];
        [error release];
        [callCenter release];
        return;
    }
    [callCenter release];
    
    LinphoneProxyConfig* proxyCfg;
    //get default proxy
    linphone_core_get_default_proxy(theLinphoneCore,&proxyCfg);
    LinphoneCallParams* lcallParams = linphone_core_create_default_call_parameters(theLinphoneCore);
    if([self lpConfigBoolForKey:@"edge_opt_preference"]) {
        bool low_bandwidth = self.network == network_2g;
        if(low_bandwidth) {
            [LinphoneLogger log:LinphoneLoggerLog format:@"Low bandwidth mode"];
        }
        linphone_call_params_enable_low_bandwidth(lcallParams, low_bandwidth);
    }
    LinphoneCall* call=NULL;
    
    BOOL addressIsASCII = [address canBeConvertedToEncoding:[NSString defaultCStringEncoding]];
    
    if ([address length] == 0) return; //just return
    if( !addressIsASCII ){
        UIAlertView* error = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Invalid SIP address",nil)
                                                        message:NSLocalizedString(@"The address should only contain ASCII data",nil)
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"Continue",nil)
                                              otherButtonTitles:nil];
        [error show];
        [error release];
        
    }
    LinphoneAddress* linphoneAddress = linphone_core_interpret_url(theLinphoneCore, [address cStringUsingEncoding:[NSString defaultCStringEncoding]]);
    
    if (linphoneAddress) {
        
        if(displayName!=nil) {
            linphone_address_set_display_name(linphoneAddress,[displayName cStringUsingEncoding:[NSString defaultCStringEncoding]]);
        }
        if ([[LinphoneManager instance] lpConfigBoolForKey:@"override_domain_with_default_one"])
            linphone_address_set_domain(linphoneAddress, [[[LinphoneManager instance] lpConfigStringForKey:@"domain" forSection:@"wizard"] cStringUsingEncoding:[NSString defaultCStringEncoding]]);
        if(transfer) {
            linphone_core_transfer_call(theLinphoneCore, linphone_core_get_current_call(theLinphoneCore), [address cStringUsingEncoding:[NSString defaultCStringEncoding]]);
        } else {
            call=linphone_core_invite_address_with_params(theLinphoneCore, linphoneAddress, lcallParams);
        }
        linphone_address_destroy(linphoneAddress);
        
    } else {
        
        UIAlertView* error = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Invalid SIP address",nil)
                                                        message:NSLocalizedString(@"Either configure a SIP proxy server from settings prior to place a call or use a valid SIP address (I.E sip:john@example.net)",nil)
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"Continue",nil)
                                              otherButtonTitles:nil];
        [error show];
        [error release];
        
    }
    
    
    if (call) {
        // The LinphoneCallAppData object should be set on call creation with callback
        // - (void)onCall:StateChanged:withMessage:. If not, we are in big trouble and expect it to crash
        // We are NOT responsible for creating the AppData. 
        LinphoneCallAppData* data=(LinphoneCallAppData*)linphone_call_get_user_pointer(call);
        if (data==nil)
            [LinphoneLogger log:LinphoneLoggerError format:@"New call instanciated but app data was not set. Expect it to crash."];
        /* will be used later to notify user if video was not activated because of the linphone core*/
        data->videoRequested = linphone_call_params_video_enabled(lcallParams);
    }
    linphone_call_params_destroy(lcallParams);
}



//接听电话
- (void)acceptCall:(LinphoneCall *)call {
    LinphoneCallParams* lcallParams = linphone_core_create_call_params(theLinphoneCore,call);
    if([self lpConfigBoolForKey:@"edge_opt_preference"]) {
        bool low_bandwidth = self.network == network_2g;
        if(low_bandwidth) {
            [LinphoneLogger log:LinphoneLoggerLog format:@"Low bandwidth mode"];
        }
        linphone_call_params_enable_low_bandwidth(lcallParams, low_bandwidth);
    }
    
    linphone_core_accept_call_with_params(theLinphoneCore,call, lcallParams);
}

- (NetworkType)network {
    if( [[[UIDevice currentDevice] systemVersion] floatValue] < 7 ){
        UIApplication *app = [UIApplication sharedApplication];
        NSArray *subviews = [[[app valueForKey:@"statusBar"] valueForKey:@"foregroundView"]    subviews];
        NSNumber *dataNetworkItemView = nil;
        
        for (id subview in subviews) {
            if([subview isKindOfClass:[NSClassFromString(@"UIStatusBarDataNetworkItemView") class]]) {
                dataNetworkItemView = subview;
                break;
            }
        }
        
        NSNumber *number = (NSNumber*)[dataNetworkItemView valueForKey:@"dataNetworkType"];
        return [number intValue];
    } else {
        CTTelephonyNetworkInfo* info = [[CTTelephonyNetworkInfo alloc] init];
        NSString* currentRadio = info.currentRadioAccessTechnology;
        if( [currentRadio isEqualToString:CTRadioAccessTechnologyEdge]){
            return network_2g;
        } else if ([currentRadio isEqualToString:CTRadioAccessTechnologyLTE]){
            return network_4g;
        }
        return network_3g;
    }
}

- (void)migrateFromUserPrefs {
    static const char* migration_flag = "userpref_migration_done";
    
    if( configDb == nil ) return;
    
    if( lp_config_get_int(configDb, LINPHONERC_APPLICATION_KEY, migration_flag, 0) ){
        Linphone_log(@"UserPrefs migration already performed, skip");
        return;
    }
    
    NSDictionary* defaults = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    NSArray* defaults_keys = [defaults allKeys];
    NSDictionary* values   = @{@"backgroundmode_preference" :@YES,
                               @"debugenable_preference"    :@NO,
                               @"start_at_boot_preference"  :@YES};
    BOOL shouldSync        = FALSE;
    
    Linphone_log(@"%lu user prefs", (unsigned long)[defaults_keys count]);
    
    for( NSString* userpref in values ){
        if( [defaults_keys containsObject:userpref] ){
            Linphone_log(@"Migrating %@ from user preferences: %d", userpref, [[defaults objectForKey:userpref] boolValue]);
            lp_config_set_int(configDb, LINPHONERC_APPLICATION_KEY, [userpref UTF8String], [[defaults objectForKey:userpref] boolValue]);
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:userpref];
            shouldSync = TRUE;
        } else if ( lp_config_get_string(configDb, LINPHONERC_APPLICATION_KEY, [userpref UTF8String], NULL) == NULL ){
            // no default value found in our linphonerc, we need to add them
            lp_config_set_int(configDb, LINPHONERC_APPLICATION_KEY, [userpref UTF8String], [[values objectForKey:userpref] boolValue]);
        }
    }
    
    if( shouldSync ){
        Linphone_log(@"Synchronizing...");
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    // don't get back here in the future
    lp_config_set_int(configDb, LINPHONERC_APPLICATION_KEY, migration_flag, 1);
}


static void audioRouteChangeListenerCallback (
                                              void                   *inUserData,                                 // 1
                                              AudioSessionPropertyID inPropertyID,                                // 2
                                              UInt32                 inPropertyValueSize,                         // 3
                                              const void             *inPropertyValue                             // 4
) {
    if (inPropertyID != kAudioSessionProperty_AudioRouteChange) return; // 5
    LinphoneManager* lm = (LinphoneManager*)inUserData;
    
    bool speakerEnabled = false;
    CFStringRef lNewRoute = CFSTR("Unknown");
    UInt32 lNewRouteSize = sizeof(lNewRoute);
    OSStatus lStatus = AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &lNewRouteSize, &lNewRoute);
    if (!lStatus && lNewRouteSize > 0) {
        NSString *route = (NSString *) lNewRoute;
        [LinphoneLogger logc:LinphoneLoggerLog format:"Current audio route is [%s]", [route cStringUsingEncoding:[NSString defaultCStringEncoding]]];
        
        speakerEnabled = [route isEqualToString: @"Speaker"] ||
        [route isEqualToString: @"SpeakerAndMicrophone"];
        if (![LinphoneManager runningOnIpad] && [route isEqualToString:@"HeadsetBT"] && !speakerEnabled) {
//            lm.bluetoothEnabled = TRUE;
//            lm.bluetoothAvailable = TRUE;
//            NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
//                                  [NSNumber numberWithBool:lm.bluetoothAvailable], @"available", nil];
//            [[NSNotificationCenter defaultCenter] postNotificationName:kLinphoneBluetoothAvailabilityUpdate object:lm userInfo:dict];
        } else {
//            lm.bluetoothEnabled = FALSE;
        }
        CFRelease(lNewRoute);
    }
    
    if(speakerEnabled != lm.speakerEnabled) { // Reforce value
        lm.speakerEnabled = lm.speakerEnabled;
    }
}

+ (NSString*)documentFile:(NSString*)file {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsPath = [paths objectAtIndex:0];
    return [documentsPath stringByAppendingPathComponent:file];
}

+ (BOOL)isRunningTests {
    NSDictionary *environment = [[NSProcessInfo processInfo] environment];
    NSString *injectBundle = environment[@"XCInjectBundle"];
    return [[injectBundle pathExtension] isEqualToString:@"xctest"];
}

- (SCNetworkReachabilityRef) getProxyReachability {
    return proxyReachability;
}

static BOOL libStarted = FALSE;

//初始化startLibLinphone *
- (void)startLibLinphone {
    
    pushCallIDs = [[NSMutableArray alloc] init ];
    speakerEnabled = FALSE;
    
    if ( libStarted ) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Liblinphone is already initialized!"];
        return;
    }
    
    libStarted = TRUE;
    
    signal(SIGPIPE, SIG_IGN);
    
    // create linphone core
    [self createLinphoneCore];
    linphone_core_migrate_to_multi_transport(theLinphoneCore);
    
    // init audio session (just getting the instance will init)
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    BOOL bAudioInputAvailable= audioSession.inputAvailable;
    NSError* err;
    
    if( ![audioSession setActive:NO error: &err] && err ){
        NSLog(@"audioSession setActive failed: %@", [err description]);
    }
    if(!bAudioInputAvailable){
        UIAlertView* error = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"No microphone",nil)
                                                        message:NSLocalizedString(@"You need to plug a microphone to your device to use this application.",nil)
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"Ok",nil)
                                              otherButtonTitles:nil ,nil];
        [error show];
        [error release];
    }
    
    if ([UIApplication sharedApplication].applicationState ==  UIApplicationStateBackground) {
        //go directly to bg mode
        [self enterBackgroundMode];
    }
    
}

//退到后台
static int comp_call_state_paused  (const LinphoneCall* call, const void* param) {
    return linphone_call_get_state(call) != LinphoneCallPaused;
}

- (BOOL)enterBackgroundMode {
    LinphoneProxyConfig* proxyCfg;
    linphone_core_get_default_proxy(theLinphoneCore, &proxyCfg);
    BOOL shouldEnterBgMode=FALSE;
    
    //handle proxy config if any
    if (proxyCfg) {
        if ([[LinphoneManager instance] lpConfigBoolForKey:@"backgroundmode_preference"] ||
            [[LinphoneManager instance] lpConfigBoolForKey:@"pushnotification_preference"]) {
            
            //For registration register
            [self refreshRegisters];
        }
        
        if ([[LinphoneManager instance] lpConfigBoolForKey:@"backgroundmode_preference"]) {
            
            //register keepalive
            if ([[UIApplication sharedApplication] setKeepAliveTimeout:600/*(NSTimeInterval)linphone_proxy_config_get_expires(proxyCfg)*/
                                                               handler:^{
                                                                   [LinphoneLogger logc:LinphoneLoggerWarning format:"keepalive handler"];
                                                                   if (mLastKeepAliveDate)
                                                                       [mLastKeepAliveDate release];
                                                                   mLastKeepAliveDate=[NSDate date];
                                                                   [mLastKeepAliveDate retain];
                                                                   if (theLinphoneCore == nil) {
                                                                       [LinphoneLogger logc:LinphoneLoggerWarning format:"It seems that Linphone BG mode was deactivated, just skipping"];
                                                                       return;
                                                                   }
                                                                   //kick up network cnx, just in case
                                                                   [self refreshRegisters];
                                                                   linphone_core_iterate(theLinphoneCore);
                                                               }
                 ]) {
                
                
                [LinphoneLogger logc:LinphoneLoggerLog format:"keepalive handler succesfully registered"];
            } else {
                [LinphoneLogger logc:LinphoneLoggerLog format:"keepalive handler cannot be registered"];
            }
            shouldEnterBgMode=TRUE;
        }
    }
    
    LinphoneCall* currentCall = linphone_core_get_current_call(theLinphoneCore);
    const MSList* callList = linphone_core_get_calls(theLinphoneCore);
    if (!currentCall //no active call
        && callList // at least one call in a non active state
        && ms_list_find_custom((MSList*)callList, (MSCompareFunc) comp_call_state_paused, NULL)) {
        [self startCallPausedLongRunningTask];
    }
    if (callList){
        /*if at least one call exist, enter normal bg mode */
        shouldEnterBgMode=TRUE;
    }
    /*stop the video preview*/
    if (theLinphoneCore){
        linphone_core_enable_video_preview(theLinphoneCore, FALSE);
        linphone_core_iterate(theLinphoneCore);
    }
    linphone_core_stop_dtmf_stream(theLinphoneCore);
    
    [LinphoneLogger logc:LinphoneLoggerLog format:"Entering [%s] bg mode",shouldEnterBgMode?"normal":"lite"];
    
    if (!shouldEnterBgMode ) {
        if([[LinphoneManager instance] lpConfigBoolForKey:@"pushnotification_preference"]) {
            [LinphoneLogger logc:LinphoneLoggerLog format:"Keeping lc core to handle push"];
            /*destroy voip socket if any and reset connectivity mode*/
//            connectivity=none;
            linphone_core_set_network_reachable(theLinphoneCore, FALSE);
            return YES;
        }
        return NO;
        
    } else
        return YES;
}



- (void)createLinphoneCore {
    
    if (theLinphoneCore != nil) {
        [LinphoneLogger logc:LinphoneLoggerLog format:"linphonecore is already created"];
        return;
    }
    [LinphoneLogger logc:LinphoneLoggerLog format:"Create linphonecore"];
    
    ms_init(); // Need to initialize mediastreamer2 before loading the plugins
    
    libmsilbc_init();
#if defined (HAVE_SILK)
    libmssilk_init();
#endif
#ifdef HAVE_AMR
    libmsamr_init(); //load amr plugin if present from the liblinphone sdk
#endif
#ifdef HAVE_X264
    libmsx264_init(); //load x264 plugin if present from the liblinphone sdk
#endif
#ifdef HAVE_OPENH264
    libmsopenh264_init(); //load openh264 plugin if present from the liblinphone sdk
#endif
    
#if HAVE_G729
    libmsbcg729_init(); // load g729 plugin
#endif
    
    /*to make sure we don't loose debug trace*/
    if ([self lpConfigBoolForKey:@"debugenable_preference"]) {
        linphone_core_enable_logs_with_cb((OrtpLogFunc)linphone_iphone_log_handler);
        ortp_set_log_level_mask(ORTP_DEBUG|ORTP_MESSAGE|ORTP_WARNING|ORTP_ERROR|ORTP_FATAL);
        /*must be done before creating linphone core to get its traces too*/
    }
    linphone_core_set_log_collection_path([[LinphoneManager cacheDirectory] UTF8String]);
    linphone_core_enable_log_collection([self lpConfigBoolForKey:@"debugenable_preference"]);
    
    
    theLinphoneCore = linphone_core_new_with_config (&linphonec_vtable
                                                     ,configDb
                                                     ,self /* user_data */);
    
    
    
    /* set the CA file no matter what, since the remote provisioning could be hitting an HTTPS server */
    const char* lRootCa = [[LinphoneManager bundleFile:@"rootca.pem"] cStringUsingEncoding:[NSString defaultCStringEncoding]];
    linphone_core_set_root_ca(theLinphoneCore, lRootCa);
    
    /* The core will call the linphone_iphone_configuring_status_changed callback when the remote provisioning is loaded (or skipped).
     Wait for this to finish the code configuration */
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionInterrupted:) name:AVAudioSessionInterruptionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(globalStateChangedNotificationHandler:) name:kLinphoneGlobalStateUpdate object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(configuringStateChangedNotificationHandler:) name:kLinphoneConfiguringStateUpdate object:nil];
    
    /*call iterate once immediately in order to initiate background connections with sip server or remote provisioning grab, if any */
    linphone_core_iterate(theLinphoneCore);
    // start scheduler
    mIterateTimer = [NSTimer scheduledTimerWithTimeInterval:0.02
                                                     target:self
                                                   selector:@selector(iterate)
                                                   userInfo:nil
                                                    repeats:YES];
}
- (void)iterate {
    linphone_core_iterate(theLinphoneCore);
}


- (void)configurePushTokenForProxyConfig:(LinphoneProxyConfig*)proxyCfg{
    NSData *tokenData =  pushNotificationToken;
    if(tokenData != nil && [self lpConfigBoolForKey:@"pushnotification_preference"]) {
        const unsigned char *tokenBuffer = [tokenData bytes];
        NSMutableString *tokenString = [NSMutableString stringWithCapacity:[tokenData length]*2];
        for(int i = 0; i < [tokenData length]; ++i) {
            [tokenString appendFormat:@"%02X", (unsigned int)tokenBuffer[i]];
        }
        // NSLocalizedString(@"IC_MSG", nil); // Fake for genstrings
        // NSLocalizedString(@"IM_MSG", nil); // Fake for genstrings
#ifdef DEBUG
#define APPMODE_SUFFIX @"dev"
#else
#define APPMODE_SUFFIX @"prod"
#endif
        NSString *params = [NSString stringWithFormat:@"app-id=%@.%@;pn-type=apple;pn-tok=%@;pn-msg-str=IM_MSG;pn-call-str=IC_MSG;pn-call-snd=ring.caf;pn-msg-snd=msg.caf", [[NSBundle mainBundle] bundleIdentifier],APPMODE_SUFFIX,tokenString];
        
        linphone_proxy_config_set_contact_uri_parameters(proxyCfg, [params UTF8String]);
        linphone_proxy_config_set_contact_parameters(proxyCfg, NULL);
    } else {
        // no push token:
        linphone_proxy_config_set_contact_uri_parameters(proxyCfg, NULL);
        linphone_proxy_config_set_contact_parameters(proxyCfg, NULL);
    }
}

- (void)setPushNotificationToken:(NSData *)apushNotificationToken {
    if(apushNotificationToken == pushNotificationToken) {
        return;
    }
    if(pushNotificationToken != nil) {
        [pushNotificationToken release];
        pushNotificationToken = nil;
    }
    
    if(apushNotificationToken != nil) {
        pushNotificationToken = [apushNotificationToken retain];
    }
    LinphoneProxyConfig *cfg=nil;
    linphone_core_get_default_proxy(theLinphoneCore, &cfg);
    if (cfg ) {
        linphone_proxy_config_edit(cfg);
        [self configurePushTokenForProxyConfig: cfg];
        linphone_proxy_config_done(cfg);
    }
}

- (void)lpConfigSetBool:(BOOL)value forKey:(NSString*)key {
    [self lpConfigSetBool:value forKey:key forSection:[NSString stringWithUTF8String:LINPHONERC_APPLICATION_KEY]];
}
- (void)lpConfigSetBool:(BOOL)value forKey:(NSString*)key forSection:(NSString *)section {
    return [self lpConfigSetInt:(NSInteger)(value == TRUE) forKey:key forSection:section];
}

- (void)lpConfigSetInt:(NSInteger)value forKey:(NSString*)key forSection:(NSString *)section {
    if (!key) return;
    lp_config_set_int(configDb, [section UTF8String], [key UTF8String], (int)value );
}

- (void)destroyLibLinphone {
    [mIterateTimer invalidate];
    //just in case
    [self removeCTCallCenterCb];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (theLinphoneCore != nil) { //just in case application terminate before linphone core initialization
        [LinphoneLogger logc:LinphoneLoggerLog format:"Destroy linphonecore"];
        linphone_core_destroy(theLinphoneCore);
        theLinphoneCore = nil;
        ms_exit(); // Uninitialize mediastreamer2
        
        // Post event
        NSDictionary *dict = [NSDictionary dictionaryWithObject:[NSValue valueWithPointer:theLinphoneCore] forKey:@"core"];
        [[NSNotificationCenter defaultCenter] postNotificationName:kLinphoneCoreUpdate object:[LinphoneManager instance] userInfo:dict];
        
        SCNetworkReachabilityUnscheduleFromRunLoop(proxyReachability, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        if (proxyReachability)
            CFRelease(proxyReachability);
        proxyReachability=nil;
        
    }
    libStarted  = FALSE;
}

+ (NSString*)bundleFile:(NSString*)file {
    return [[NSBundle mainBundle] pathForResource:[file stringByDeletingPathExtension] ofType:[file pathExtension]];
}

- (void)audioSessionInterrupted:(NSNotification *)notification
{
    int interruptionType = [notification.userInfo[AVAudioSessionInterruptionTypeKey] intValue];
    if (interruptionType == AVAudioSessionInterruptionTypeBegan) {
        [self beginInterruption];
    } else if (interruptionType == AVAudioSessionInterruptionTypeEnded) {
        [self endInterruption];
    }
}

- (void)beginInterruption {
    LinphoneCall* c = linphone_core_get_current_call(theLinphoneCore);
    [LinphoneLogger logc:LinphoneLoggerLog format:"Sound interruption detected!"];
    if (c && linphone_call_get_state(c) == LinphoneCallStreamsRunning) {
        linphone_core_pause_call(theLinphoneCore, c);
    }
}

- (void)endInterruption {
    [LinphoneLogger logc:LinphoneLoggerLog format:"Sound interruption ended!"];
}

#pragma mark -

static void linphone_iphone_call_state(LinphoneCore *lc, LinphoneCall* call, LinphoneCallState state,const char* message) {
    
    
    NSLog(@"1111111111111111//************************************操他大爷啦诶了****************/////1111111");
    [(LinphoneManager*)linphone_core_get_user_data(lc) onCall:call StateChanged: state withMessage:  message];
}
- (void)onRegister:(LinphoneCore *)lc cfg:(LinphoneProxyConfig*) cfg state:(LinphoneRegistrationState) state message:(const char*) message {
    [LinphoneLogger logc:LinphoneLoggerLog format:"NEW REGISTRATION STATE: '%s' (message: '%s')", linphone_registration_state_to_string(state), message];
    
    // Post event
    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSNumber numberWithInt:state], @"state",
                          [NSValue valueWithPointer:cfg], @"cfg",
                          [NSString stringWithUTF8String:message], @"message",
                          nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kLinphoneRegistrationUpdate object:self userInfo:dict];
}
static void linphone_iphone_registration_state(LinphoneCore *lc, LinphoneProxyConfig* cfg, LinphoneRegistrationState state,const char* message) {
    [(LinphoneManager*)linphone_core_get_user_data(lc) onRegister:lc cfg:cfg state:state message:message];
}


- (void)displayStatus:(NSString*) message {
    // Post event
    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          message, @"message",
                          nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kLinphoneDisplayStatusUpdate object:self userInfo:dict];
}
static void linphone_iphone_display_status(struct _LinphoneCore * lc, const char * message) {
    NSString* status = [[NSString alloc] initWithCString:message encoding:[NSString defaultCStringEncoding]];
    [(LinphoneManager*)linphone_core_get_user_data(lc)  displayStatus:status];
    [status release];
}


static void linphone_iphone_log(struct _LinphoneCore * lc, const char * message) {
    NSString* log = [NSString stringWithCString:message encoding:[NSString defaultCStringEncoding]];
    NSLog(log, NULL);
    
}

- (void)onMessageReceived:(LinphoneCore *)lc room:(LinphoneChatRoom *)room  message:(LinphoneChatMessage*)msg {
    
    if (silentPushCompletion) {
        
        // we were woken up by a silent push. Call the completion handler with NEWDATA
        // so that the push is notified to the user
        [LinphoneLogger log:LinphoneLoggerLog format:@"onMessageReceived - handler %p", silentPushCompletion];
        silentPushCompletion(UIBackgroundFetchResultNewData);
        silentPushCompletion = nil;
    }
    const LinphoneAddress* remoteAddress = linphone_chat_message_get_from_address(msg);
    char* c_address                      = linphone_address_as_string_uri_only(remoteAddress);
    NSString* address                    = [NSString stringWithUTF8String:c_address];
    const char* call_id                  = linphone_chat_message_get_custom_header(msg, "Call-ID");
    NSString* callID                     = [NSString stringWithUTF8String:call_id];
    
    ms_free(c_address);
    
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        
        ABRecordRef contact = [fastAddressBook getContact:address];
        if(contact) {
            address = [FastAddressBook getContactDisplayName:contact];
        } else {
            if ([[LinphoneManager instance] lpConfigBoolForKey:@"show_contacts_emails_preference"] == true) {
                LinphoneAddress *linphoneAddress = linphone_address_new([address cStringUsingEncoding:[NSString defaultCStringEncoding]]);
                address = [NSString stringWithUTF8String:linphone_address_get_username(linphoneAddress)];
                linphone_address_destroy(linphoneAddress);
            }
        }
        if(address == nil) {
            address = NSLocalizedString(@"Unknown", nil);
        }
        
        // Create a new notification
        UILocalNotification* notif = [[[UILocalNotification alloc] init] autorelease];
        if (notif) {
            notif.repeatInterval = 0;
            if( [[UIDevice currentDevice].systemVersion floatValue] >= 8){
                notif.category       = @"incoming_msg";
            }
            notif.alertBody      = [NSString  stringWithFormat:NSLocalizedString(@"IM_MSG",nil), address];
            notif.alertAction    = NSLocalizedString(@"Show", nil);
            notif.soundName      = @"msg.caf";
            notif.userInfo       = @{@"from":address, @"call-id":callID};
            
            [[UIApplication sharedApplication] presentLocalNotificationNow:notif];
        }
    }
    
    // Post event
    NSDictionary* dict = @{@"room"        :[NSValue valueWithPointer:room],
                           @"from_address":[NSValue valueWithPointer:linphone_chat_message_get_from_address(msg)],
                           @"message"     :[NSValue valueWithPointer:msg],
                           @"call-id"     : callID};
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kLinphoneTextReceived object:self userInfo:dict];
}

static void linphone_iphone_message_received(LinphoneCore *lc, LinphoneChatRoom *room, LinphoneChatMessage *message) {
    [(LinphoneManager*)linphone_core_get_user_data(lc) onMessageReceived:lc room:room message:message];
}

#pragma mark - Transfert State Functions

static void linphone_iphone_transfer_state_changed(LinphoneCore* lc, LinphoneCall* call, LinphoneCallState state) {
}


#pragma mark - Message composition start

- (void)onMessageComposeReceived:(LinphoneCore*)core forRoom:(LinphoneChatRoom*)room {
    [[NSNotificationCenter defaultCenter] postNotificationName:kLinphoneTextComposeEvent
                                                        object:self
                                                      userInfo:@{@"room":[NSValue valueWithPointer:room]}];
}

static void linphone_iphone_is_composing_received(LinphoneCore *lc, LinphoneChatRoom *room){
    [(LinphoneManager*)linphone_core_get_user_data(lc) onMessageComposeReceived:lc forRoom:room];
}

#pragma mark - Configuring status changed

static void linphone_iphone_configuring_status_changed(LinphoneCore *lc, LinphoneConfiguringState status, const char *message) {
    [(LinphoneManager*)linphone_core_get_user_data(lc) onConfiguringStatusChanged:status withMessage:message];
}

-(void)onConfiguringStatusChanged:(LinphoneConfiguringState)status withMessage:(const char*)message {
    [LinphoneLogger log:LinphoneLoggerLog format:@"onConfiguringStatusChanged: %d (message: %s)", status, message];
    
    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSNumber numberWithInt:status], @"state",
                          [NSString stringWithUTF8String:message?message:""], @"message",
                          nil];
    
    // dispatch the notification asynchronously
    dispatch_async(dispatch_get_main_queue(), ^(void){
        [[NSNotificationCenter defaultCenter] postNotificationName:kLinphoneConfiguringStateUpdate object:self userInfo:dict];
    });
}


-(void)configuringStateChangedNotificationHandler:(NSNotification*)notif {
    if( (LinphoneConfiguringState)[[[notif userInfo] valueForKey:@"state"] integerValue] == LinphoneConfiguringSuccessful){
        wasRemoteProvisioned = TRUE;
    } else {
        wasRemoteProvisioned = FALSE;
    }
}

#pragma mark - Global state change

static void linphone_iphone_global_state_changed(LinphoneCore *lc, LinphoneGlobalState gstate, const char *message) {
    [(LinphoneManager*)linphone_core_get_user_data(lc) onGlobalStateChanged:gstate withMessage:message];
}

-(void)onGlobalStateChanged:(LinphoneGlobalState)state withMessage:(const char*)message {
    [LinphoneLogger log:LinphoneLoggerLog format:@"onGlobalStateChanged: %d (message: %s)", state, message];
    
    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSNumber numberWithInt:state], @"state",
                          [NSString stringWithUTF8String:message?message:""], @"message",
                          nil];
    
    // dispatch the notification asynchronously
    dispatch_async(dispatch_get_main_queue(), ^(void){
        [[NSNotificationCenter defaultCenter] postNotificationName:kLinphoneGlobalStateUpdate object:self userInfo:dict];
    });
}


-(void)globalStateChangedNotificationHandler:(NSNotification*)notif {
    if( (LinphoneGlobalState)[[[notif userInfo] valueForKey:@"state"] integerValue] == LinphoneGlobalOn){
        [self finishCoreConfiguration];
    }
}
/** Should be called once per linphone_core_new() */
- (void)finishCoreConfiguration {
    
    //get default config from bundle
    NSString *zrtpSecretsFileName = [LinphoneManager documentFile:@"zrtp_secrets"];
//    NSString *chatDBFileName      = [LinphoneManager documentFile:kLinphoneInternalChatDBFilename];
    const char* lRootCa           = [[LinphoneManager bundleFile:@"rootca.pem"] cStringUsingEncoding:[NSString defaultCStringEncoding]];
    
//    linphone_core_set_user_agent(theLinphoneCore, [[[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"] stringByAppendingString:@"Iphone"] UTF8String], LINPHONE_IOS_VERSION);
    
    [_contactSipField release];
    _contactSipField = [[self lpConfigStringForKey:@"contact_im_type_value" withDefault:@"SIP"] retain];
    
    
    fastAddressBook = [[FastAddressBook alloc] init];
    
    linphone_core_set_root_ca(theLinphoneCore, lRootCa);
    // Set audio assets
    const char* lRing = [[LinphoneManager bundleFile:@"ring.wav"] cStringUsingEncoding:[NSString defaultCStringEncoding]];
    linphone_core_set_ring(theLinphoneCore, lRing);
    const char* lRingBack = [[LinphoneManager bundleFile:@"ringback.wav"] cStringUsingEncoding:[NSString defaultCStringEncoding]];
    linphone_core_set_ringback(theLinphoneCore, lRingBack);
    const char* lPlay = [[LinphoneManager bundleFile:@"hold.wav"] cStringUsingEncoding:[NSString defaultCStringEncoding]];
    linphone_core_set_play_file(theLinphoneCore, lPlay);
    
    linphone_core_set_zrtp_secrets_file(theLinphoneCore, [zrtpSecretsFileName cStringUsingEncoding:[NSString defaultCStringEncoding]]);
//    linphone_core_set_chat_database_path(theLinphoneCore, [chatDBFileName cStringUsingEncoding:[NSString defaultCStringEncoding]]);
//    
//    // we need to proceed to the migration *after* the chat database was opened, so that we know it is in consistent state
////    BOOL migrated = [self migrateChatDBIfNeeded:theLinphoneCore];
//    if( migrated ){
//        // if a migration was performed, we should reinitialize the chat database
//        linphone_core_set_chat_database_path(theLinphoneCore, [chatDBFileName cStringUsingEncoding:[NSString defaultCStringEncoding]]);
//    }
    
    /* AVPF migration */
    if( [self lpConfigBoolForKey:@"avpf_migration_done" forSection:@"app"] == FALSE ){
        const MSList* proxies = linphone_core_get_proxy_config_list(theLinphoneCore);
        while(proxies){
            LinphoneProxyConfig* proxy = (LinphoneProxyConfig*)proxies->data;
            const char* addr = linphone_proxy_config_get_addr(proxy);
            // we want to enable AVPF for the proxies
            if( addr && strstr(addr, "sip.linphone.org") != 0 ){
                Linphone_log(@"Migrating proxy config to use AVPF");
                linphone_proxy_config_enable_avpf(proxy, TRUE);
            }
            proxies = proxies->next;
        }
        [self lpConfigSetBool:TRUE forKey:@"avpf_migration_done"];
    }
    /* Quality Reporting migration */
    if( [self lpConfigBoolForKey:@"quality_report_migration_done" forSection:@"app"] == FALSE ){
        const MSList* proxies = linphone_core_get_proxy_config_list(theLinphoneCore);
        while(proxies){
            LinphoneProxyConfig* proxy = (LinphoneProxyConfig*)proxies->data;
            const char* addr = linphone_proxy_config_get_addr(proxy);
            // we want to enable quality reporting for the proxies that are on linphone.org
            if( addr && strstr(addr, "sip.linphone.org") != 0 ){
                Linphone_log(@"Migrating proxy config to send quality report");
                linphone_proxy_config_set_quality_reporting_collector(proxy, "sip:voip-metrics@sip.linphone.org");
                linphone_proxy_config_set_quality_reporting_interval(proxy, 180);
                linphone_proxy_config_enable_quality_reporting(proxy, TRUE);
            }
            proxies = proxies->next;
        }
        [self lpConfigSetBool:TRUE forKey:@"quality_report_migration_done"];
    }
    
    [self setupNetworkReachabilityCallback];
    
    NSString* path = [LinphoneManager bundleFile:@"nowebcamCIF.jpg"];
    if (path) {
        const char* imagePath = [path cStringUsingEncoding:[NSString defaultCStringEncoding]];
        [LinphoneLogger logc:LinphoneLoggerLog format:"Using '%s' as source image for no webcam", imagePath];
        linphone_core_set_static_picture(theLinphoneCore, imagePath);
    }
    
    /*DETECT cameras*/
    frontCamId= backCamId=nil;
    char** camlist = (char**)linphone_core_get_video_devices(theLinphoneCore);
    for (char* cam = *camlist;*camlist!=NULL;cam=*++camlist) {
        if (strcmp(FRONT_CAM_NAME, cam)==0) {
            frontCamId = cam;
            //great set default cam to front
            linphone_core_set_video_device(theLinphoneCore, cam);
        }
        if (strcmp(BACK_CAM_NAME, cam)==0) {
            backCamId = cam;
        }
        
    }
    
    
        PayloadType *pt=linphone_core_find_payload_type(theLinphoneCore,"SILK",24000,-1);
        if (pt) {
            linphone_core_enable_payload_type(theLinphoneCore,pt,TRUE);
            [LinphoneLogger logc:LinphoneLoggerWarning format:"SILK/24000 and video disabled on old iPhone 3G"];
        }
        linphone_core_enable_video(theLinphoneCore, TRUE, TRUE);
   
    
    [LinphoneLogger logc:LinphoneLoggerWarning format:"Linphone [%s]  started on [%s]", linphone_core_get_version(), [[UIDevice currentDevice].model cStringUsingEncoding:[NSString defaultCStringEncoding]]];
    
    
    // Post event
    NSDictionary *dict = [NSDictionary dictionaryWithObject:[NSValue valueWithPointer:theLinphoneCore]
                                                     forKey:@"core"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kLinphoneCoreUpdate
                                                        object:[LinphoneManager instance]
                                                      userInfo:dict];
    
}

- (void)setupNetworkReachabilityCallback {
    SCNetworkReachabilityContext *ctx=NULL;
    //any internet cnx
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    
    if (proxyReachability) {
        [LinphoneLogger logc:LinphoneLoggerLog format:"Cancelling old network reachability"];
        SCNetworkReachabilityUnscheduleFromRunLoop(proxyReachability, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        CFRelease(proxyReachability);
        proxyReachability = nil;
    }
    
    // This notification is used to detect SSID change (switch of Wifi network). The ReachabilityCallback is
    // not triggered when switching between 2 private Wifi...
    // Since we cannot be sure we were already observer, remove ourself each time... to be improved
//    _SSID = [[LinphoneManager getCurrentWifiSSID] retain];
//    CFNotificationCenterRemoveObserver(
//                                       CFNotificationCenterGetDarwinNotifyCenter(),
//                                       self,
//                                       CFSTR("com.apple.system.config.network_change"),
//                                       NULL);
//    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
//                                    self,
//                                    networkReachabilityNotification,
//                                    CFSTR("com.apple.system.config.network_change"),
//                                    NULL,
//                                    CFNotificationSuspensionBehaviorDeliverImmediately);
//    
//    proxyReachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr*)&zeroAddress);
//    
//    if (!SCNetworkReachabilitySetCallback(proxyReachability, (SCNetworkReachabilityCallBack)networkReachabilityCallBack, ctx)){
//        [LinphoneLogger logc:LinphoneLoggerError format:"Cannot register reachability cb: %s", SCErrorString(SCError())];
//        return;
//    }
//    if(!SCNetworkReachabilityScheduleWithRunLoop(proxyReachability, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)){
//        [LinphoneLogger logc:LinphoneLoggerError format:"Cannot register schedule reachability cb: %s", SCErrorString(SCError())];
//        return;
//    }
    
    // this check is to know network connectivity right now without waiting for a change. Don'nt remove it unless you have good reason. Jehan
//    SCNetworkReachabilityFlags flags;
//    if (SCNetworkReachabilityGetFlags(proxyReachability, &flags)) {
//        networkReachabilityCallBack(proxyReachability,flags,nil);
//    }
}



- (NSString*)lpConfigStringForKey:(NSString*)key {
    return [self lpConfigStringForKey:key forSection:[NSString stringWithUTF8String:LINPHONERC_APPLICATION_KEY]];
}

- (NSString*)lpConfigStringForKey:(NSString*)key forSection:(NSString *)section {
    if (!key) return nil;
    const char* value = lp_config_get_string(configDb, [section UTF8String], [key UTF8String], NULL);
    if (value)
        return [NSString stringWithUTF8String:value];
    else
        return nil;
}

- (NSString*)lpConfigStringForKey:(NSString*)key withDefault:(NSString*)defaultValue {
    NSString* value = [self lpConfigStringForKey:key];
    return value?value:defaultValue;
}

static void linphone_iphone_notify_received(LinphoneCore *lc, LinphoneEvent *lev, const char *notified_event, const LinphoneContent *body) {
    [(LinphoneManager*)linphone_core_get_user_data(lc) onNotifyReceived:lc event:lev notifyEvent:notified_event content:body];
}
- (void)onNotifyReceived:(LinphoneCore *)lc event:(LinphoneEvent *)lev notifyEvent:(const char *)notified_event content:(const LinphoneContent *)body {
    // Post event
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    [dict setObject:[NSValue valueWithPointer:lev] forKey:@"event"];
    [dict setObject:[NSString stringWithUTF8String:notified_event] forKey:@"notified_event"];
    if (body != NULL) {
        [dict setObject:[NSValue valueWithPointer:body] forKey:@"content"];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kLinphoneNotifyReceived object:self userInfo:dict];
    
}

static LinphoneCoreVTable linphonec_vtable = {
    .show =NULL,
    .call_state_changed =(LinphoneCoreCallStateChangedCb)linphone_iphone_call_state,
    .registration_state_changed = linphone_iphone_registration_state,
    .notify_presence_received=NULL,
    .new_subscription_requested = NULL,
    .auth_info_requested = NULL,
    .display_status = linphone_iphone_display_status,
    .display_message=linphone_iphone_log,
    .display_warning=linphone_iphone_log,
    .display_url=NULL,
    .text_received=NULL,
    .message_received=linphone_iphone_message_received,
    .dtmf_received=NULL,
    .transfer_state_changed=linphone_iphone_transfer_state_changed,
    .is_composing_received = linphone_iphone_is_composing_received,
    .configuring_status = linphone_iphone_configuring_status_changed,
    .global_state_changed = linphone_iphone_global_state_changed,
    .notify_received = linphone_iphone_notify_received
};


- (NSInteger)lpConfigIntForKey:(NSString*)key forSection:(NSString *)section {
    if (!key) return -1;
    return lp_config_get_int(configDb, [section UTF8String], [key UTF8String], -1);
}

//后台
- (BOOL)lpConfigBoolForKey:(NSString*)key {
    return [self lpConfigBoolForKey:key forSection:[NSString stringWithUTF8String:LINPHONERC_APPLICATION_KEY]];
}
- (void)cancelLocalNotifTimerForCallId:(NSString*)callid {
    //first, make sure this callid is not already involved in a call
    MSList* calls = (MSList*)linphone_core_get_calls(theLinphoneCore);
    MSList* call = ms_list_find_custom(calls, (MSCompareFunc)comp_call_id, [callid UTF8String]);
    if (call != NULL) {
        LinphoneCallAppData* data = linphone_call_get_user_pointer((LinphoneCall*)call->data);
        if ( data->timer )
            [data->timer invalidate];
        data->timer = nil;
        return;
    }
}
- (void)acceptCallForCallId:(NSString*)callid {
    //first, make sure this callid is not already involved in a call
    MSList* calls = (MSList*)linphone_core_get_calls(theLinphoneCore);
    MSList* call = ms_list_find_custom(calls, (MSCompareFunc)comp_call_id, [callid UTF8String]);
    if (call != NULL) {
        [self acceptCall:(LinphoneCall*)call->data];
        return;
    };
}
- (BOOL)resignActive {
    linphone_core_stop_dtmf_stream(theLinphoneCore);
    
    return YES;
}
- (void)becomeActive {
    [self refreshRegisters];
    if (pausedCallBgTask) {
        [[UIApplication sharedApplication]  endBackgroundTask:pausedCallBgTask];
        pausedCallBgTask=0;
    }
    if (incallBgTask) {
        [[UIApplication sharedApplication]  endBackgroundTask:incallBgTask];
        incallBgTask=0;
    }
    
    /*IOS specific*/
    linphone_core_start_dtmf_stream(theLinphoneCore);
    
    /*start the video preview in case we are in the main view*/
    if ([LinphoneManager runningOnIpad]  && linphone_core_video_enabled(theLinphoneCore) && [self lpConfigBoolForKey:@"preview_preference"]){
        linphone_core_enable_video_preview(theLinphoneCore, TRUE);
    }
    /*check last keepalive handler date*/
    if (mLastKeepAliveDate!=Nil){
        NSDate *current=[NSDate date];
        if ([current timeIntervalSinceDate:mLastKeepAliveDate]>700){
            NSString *datestr=[mLastKeepAliveDate description];
            [LinphoneLogger logc:LinphoneLoggerWarning format:"keepalive handler was called for the last time at %@",datestr];
        }
    }
    
}

- (BOOL)lpConfigBoolForKey:(NSString*)key forSection:(NSString *)section {
    return [self lpConfigIntForKey:key forSection:section] == 1;
}

+ (NSString*)cacheDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachePath = [paths objectAtIndex:0];
    BOOL isDir = NO;
    NSError *error;
    // cache directory must be created if not existing
    if (! [[NSFileManager defaultManager] fileExistsAtPath:cachePath isDirectory:&isDir] && isDir == NO) {
        [[NSFileManager defaultManager] createDirectoryAtPath:cachePath withIntermediateDirectories:NO attributes:nil error:&error];
    }
    return cachePath;
}



- (void)onCall:(LinphoneCall*)call StateChanged:(LinphoneCallState)state withMessage:(const char *)message {
    
    // Handling wrapper
    LinphoneCallAppData* data=(LinphoneCallAppData*)linphone_call_get_user_pointer(call);
    if (!data) {
        data = [[LinphoneCallAppData alloc] init];
        linphone_call_set_user_pointer(call, data);
    }
    
    if (silentPushCompletion) {
        
        // we were woken up by a silent push. Call the completion handler with NEWDATA
        // so that the push is notified to the user
        [LinphoneLogger log:LinphoneLoggerLog format:@"onCall - handler %p", silentPushCompletion];
        silentPushCompletion(UIBackgroundFetchResultNewData);
        silentPushCompletion = nil;
    }
    
    const LinphoneAddress *addr = linphone_call_get_remote_address(call);
    NSString* address = nil;
    if(addr != NULL) {
        BOOL useLinphoneAddress = true;
        // contact name
        char* lAddress = linphone_address_as_string_uri_only(addr);
        if(lAddress) {
            NSString *normalizedSipAddress = [FastAddressBook normalizeSipURI:[NSString stringWithUTF8String:lAddress]];
            ABRecordRef contact = [fastAddressBook getContact:normalizedSipAddress];
            if(contact) {
                address = [FastAddressBook getContactDisplayName:contact];
                useLinphoneAddress = false;
            }
            ms_free(lAddress);
        }
        if(useLinphoneAddress) {
            const char* lDisplayName = linphone_address_get_display_name(addr);
            const char* lUserName = linphone_address_get_username(addr);
            if (lDisplayName)
                address = [NSString stringWithUTF8String:lDisplayName];
            else if(lUserName)
                address = [NSString stringWithUTF8String:lUserName];
        }
    }
    if(address == nil) {
        address = NSLocalizedString(@"Unknown", nil);
    }
    
    if (state == LinphoneCallIncomingReceived) {
        
        /*first step is to re-enable ctcall center*/
        CTCallCenter* lCTCallCenter = [[CTCallCenter alloc] init];
        
        /*should we reject this call ?*/
        if ([lCTCallCenter currentCalls]!=nil) {
            char *tmp=linphone_call_get_remote_address_as_string(call);
            if (tmp) {
                [LinphoneLogger logc:LinphoneLoggerLog format:"Mobile call ongoing... rejecting call from [%s]",tmp];
                ms_free(tmp);
            }
            linphone_core_decline_call(theLinphoneCore, call,LinphoneReasonBusy);
            [lCTCallCenter release];
            return;
        }
        [lCTCallCenter release];
        
        if(	[UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
            
            LinphoneCallLog* callLog=linphone_call_get_call_log(call);
            NSString* callId=[NSString stringWithUTF8String:linphone_call_log_get_call_id(callLog)];
            
            if (![[LinphoneManager instance] popPushCallID:callId]){
                // case where a remote notification is not already received
                // Create a new local notification
                data->notification = [[UILocalNotification alloc] init];
                if (data->notification) {
                    
                    // iOS8 doesn't need the timer trick for the local notification.
                    if( [[UIDevice currentDevice].systemVersion floatValue] >= 8){
                        data->notification.soundName = @"ring.caf";
                        data->notification.category = @"incoming_call";
                    } else {
                        data->notification.soundName = @"shortring.caf";
                        data->timer = [NSTimer scheduledTimerWithTimeInterval:4.0 target:self selector:@selector(localNotifContinue:) userInfo:data->notification repeats:TRUE];
                    }
                    
                    data->notification.repeatInterval = 0;
                    
                    data->notification.alertBody =[NSString  stringWithFormat:NSLocalizedString(@"IC_MSG",nil), address];
                    data->notification.alertAction = NSLocalizedString(@"Answer", nil);
                    data->notification.userInfo = @{@"callId": callId, @"timer":[NSNumber numberWithInt:1] };
                    data->notification.applicationIconBadgeNumber = 1;
                    
                    [[UIApplication sharedApplication] presentLocalNotificationNow:data->notification];
                    
                    if (!incallBgTask){
                        incallBgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler: ^{
                            [LinphoneLogger log:LinphoneLoggerWarning format:@"Call cannot ring any more, too late"];
                            [[UIApplication sharedApplication] endBackgroundTask:incallBgTask];
                            incallBgTask=0;
                        }];
                        
                        if( data->timer ){
                            [[NSRunLoop currentRunLoop] addTimer:data->timer forMode:NSRunLoopCommonModes];
                        }
                    }
                    
                }
            }
        }
    }
    
    // we keep the speaker auto-enabled state in this static so that we don't
    // force-enable it on ICE re-invite if the user disabled it.
    static BOOL speaker_already_enabled = FALSE;
    
    // Disable speaker when no more call
    if ((state == LinphoneCallEnd || state == LinphoneCallError)) {
        speaker_already_enabled = FALSE;
        if(linphone_core_get_calls_nb(theLinphoneCore) == 0) {
            [self setSpeakerEnabled:FALSE];
            [self removeCTCallCenterCb];
          
            /*IOS specific*/
            linphone_core_start_dtmf_stream(theLinphoneCore);
        }
        if (incallBgTask) {
            [[UIApplication sharedApplication]  endBackgroundTask:incallBgTask];
            incallBgTask=0;
        }
        if(data != nil && data->notification != nil) {
            LinphoneCallLog *log = linphone_call_get_call_log(call);
            
            // cancel local notif if needed
            if( data->timer ){
                [data->timer invalidate];
                data->timer = nil;
            }
            [[UIApplication sharedApplication] cancelLocalNotification:data->notification];
            
            [data->notification release];
            data->notification = nil;
            
            if(log == NULL || linphone_call_log_get_status(log) == LinphoneCallMissed) {
                UILocalNotification *notification = [[UILocalNotification alloc] init];
                notification.repeatInterval = 0;
                notification.alertBody = [NSString stringWithFormat:NSLocalizedString(@"You missed a call from %@", nil), address];
                notification.alertAction = NSLocalizedString(@"Show", nil);
                notification.userInfo = [NSDictionary dictionaryWithObject:[NSString stringWithUTF8String:linphone_call_log_get_call_id(log)] forKey:@"callLog"];
                [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
                [notification release];
            }
            
        }
    }
    
    if(state == LinphoneCallReleased) {
        if(data != NULL) {
            [data release];
            linphone_call_set_user_pointer(call, NULL);
        }
    }
    
    // Enable speaker when video
    if(state == LinphoneCallIncomingReceived ||
       state == LinphoneCallOutgoingInit ||
       state == LinphoneCallConnected ||
       state == LinphoneCallStreamsRunning) {
        if (linphone_call_params_video_enabled(linphone_call_get_current_params(call)) && !speaker_already_enabled) {
            [self setSpeakerEnabled:TRUE];
            speaker_already_enabled = TRUE;
        }
    }
    
    if (state == LinphoneCallConnected && !mCallCenter) {
        /*only register CT call center CB for connected call*/
        [self setupGSMInteraction];
    }
    // Post event
    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSValue valueWithPointer:call], @"call",
                          [NSNumber numberWithInt:state], @"state",
                          [NSString stringWithUTF8String:message], @"message", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kLinphoneCallUpdate object:self userInfo:dict];
}

- (void)localNotifContinue:(NSTimer*) timer {
    UILocalNotification* notif = [timer userInfo];
    if (notif){
        [LinphoneLogger log:LinphoneLoggerLog format:@"cancelling/presenting local notif"];
        [[UIApplication sharedApplication] cancelLocalNotification:notif];
        [[UIApplication sharedApplication] presentLocalNotificationNow:notif];
    }
}

- (void)setupGSMInteraction {
    
    [self removeCTCallCenterCb];
    mCallCenter = [[CTCallCenter alloc] init];
    [LinphoneLogger log:LinphoneLoggerLog format:@"Adding CT call center listener [%p]",mCallCenter];
    mCallCenter.callEventHandler = ^(CTCall* call) {
        // post on main thread
        [self performSelectorOnMainThread:@selector(handleGSMCallInteration:)
                               withObject:mCallCenter
                            waitUntilDone:YES];
    };
    
}
- (void)handleGSMCallInteration: (id) cCenter {
    CTCallCenter* ct = (CTCallCenter*) cCenter;
    /* pause current call, if any */
    LinphoneCall* call = linphone_core_get_current_call(theLinphoneCore);
    if ([ct currentCalls]!=nil) {
        if (call) {
            [LinphoneLogger log:LinphoneLoggerLog format:@"Pausing SIP call because GSM call"];
            linphone_core_pause_call(theLinphoneCore, call);
            [self startCallPausedLongRunningTask];
        } else if (linphone_core_is_in_conference(theLinphoneCore)) {
            [LinphoneLogger log:LinphoneLoggerLog format:@"Leaving conference call because GSM call"];
            linphone_core_leave_conference(theLinphoneCore);
            [self startCallPausedLongRunningTask];
        }
    } //else nop, keep call in paused state
}

- (void) startCallPausedLongRunningTask {
    pausedCallBgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler: ^{
        [LinphoneLogger log:LinphoneLoggerWarning format:@"Call cannot be paused any more, too late"];
        [[UIApplication sharedApplication] endBackgroundTask:pausedCallBgTask];
    }];
    [LinphoneLogger log:LinphoneLoggerLog format:@"Long running task started, remaining [%g s] because at least one call is paused"
     ,[[UIApplication  sharedApplication] backgroundTimeRemaining]];
}

-(void) removeCTCallCenterCb {
    if (mCallCenter != nil) {
        [LinphoneLogger log:LinphoneLoggerLog format:@"Removing CT call center listener [%p]",mCallCenter];
        mCallCenter.callEventHandler=NULL;
        [mCallCenter release];
    }
    mCallCenter=nil;
}

- (void)setSpeakerEnabled:(BOOL)enable {
    speakerEnabled = enable;
    
    if(enable && [self allowSpeaker]) {
        UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;
        AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute
                                 , sizeof (audioRouteOverride)
                                 , &audioRouteOverride);
   
    } else {
        UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_None;
        AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute
                                 , sizeof (audioRouteOverride)
                                 , &audioRouteOverride);
    }
    
   
}

- (bool)allowSpeaker {
    bool notallow = false;
    CFStringRef lNewRoute = CFSTR("Unknown");
    UInt32 lNewRouteSize = sizeof(lNewRoute);
    OSStatus lStatus = AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &lNewRouteSize, &lNewRoute);
    if (!lStatus && lNewRouteSize > 0) {
        NSString *route = (NSString *) lNewRoute;
        notallow = [route isEqualToString: @"Headset"] ||
        [route isEqualToString: @"Headphone"] ||
        [route isEqualToString: @"HeadphonesAndMicrophone"] ||
        [route isEqualToString: @"HeadsetInOut"] ||
        [route isEqualToString: @"Lineout"] ||
        [LinphoneManager runningOnIpad];
        CFRelease(lNewRoute);
    }
    return !notallow;
}

+ (BOOL)runningOnIpad {
#ifdef UI_USER_INTERFACE_IDIOM
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
#else
    return NO;
#endif
}

static int comp_call_id(const LinphoneCall* call , const char *callid) {
    if (linphone_call_log_get_call_id(linphone_call_get_call_log(call)) == nil) {
        ms_error ("no callid for call [%p]", call);
        return 1;
    }
    return strcmp(linphone_call_log_get_call_id(linphone_call_get_call_log(call)), callid);
}
- (void)addPushCallId:(NSString*) callid {
    //first, make sure this callid is not already involved in a call
    MSList* calls = (MSList*)linphone_core_get_calls(theLinphoneCore);
    if (ms_list_find_custom(calls, (MSCompareFunc)comp_call_id, [callid UTF8String])) {
        Linphone_warn(@"Call id [%@] already handled",callid);
        return;
    };
    if ([pushCallIDs count] > 10 /*max number of pending notif*/)
        [pushCallIDs removeObjectAtIndex:0];
    
    [pushCallIDs addObject:callid];
}

- (BOOL)popPushCallID:(NSString*) callId {
    for (NSString* pendingNotif in pushCallIDs) {
        if ([pendingNotif  compare:callId] == NSOrderedSame) {
            [pushCallIDs removeObject:pendingNotif];
            return TRUE;
        }
    }
    return FALSE;
}


+ (LinphoneCore*)getLc {
    if (theLinphoneCore==nil) {
        @throw([NSException exceptionWithName:@"LinphoneCoreException" reason:@"Linphone core not initialized yet" userInfo:nil]);
    }
    return theLinphoneCore;
}

#pragma mark - Logs Functions

//generic log handler for debug version
void linphone_iphone_log_handler(int lev, const char *fmt, va_list args){
    NSString* format = [[NSString alloc] initWithUTF8String:fmt];
    NSLogv(format, args);
    //	NSString* formatedString = [[NSString alloc] initWithFormat:format arguments:args];
    //
    //    dispatch_async(dispatch_get_main_queue(), ^{
    //        if([[LinphoneManager instance].logs count] >= LINPHONE_LOGS_MAX_ENTRY) {
    //            [[LinphoneManager instance].logs removeObjectAtIndex:0];
    //        }
    //        [[LinphoneManager instance].logs addObject:formatedString];
    //
    //        // Post event
    //        NSDictionary *dict = [NSDictionary dictionaryWithObject:formatedString forKey:@"log"];
    //        [[NSNotificationCenter defaultCenter] postNotificationName:kLinphoneLogsUpdate object:[LinphoneManager instance] userInfo:dict];
    //    });
    //
    //	[formatedString release];
    [format release];
}

- (void)refreshRegisters{
 
    linphone_core_refresh_registers(theLinphoneCore);//just to make sure REGISTRATION is up to date
}

@end