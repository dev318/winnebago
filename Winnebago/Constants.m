//
//  Constants.m
//
//  Created by Zack Smith on 8/22/11.
//  Copyright 2011 318. All rights reserved.
//

#import "Constants.h"


@implementation Constants
// Standard Notfications
// Standard Notfications
NSString * const SettingsFileResourceID = @"com.github.winnebago.settings";

# pragma mark NSNotifications
//Plugin Notifications
NSString * const PluginsHaveLoadedNotfication = @"PluginsHaveLoadedNotfication";
NSString * const NetCheckInProgressNotification = @"NetCheckInProgressNotification";
NSString * const NetCheckFinishedNotification = @"NetCheckFinishedNotification";
NSString * const NetCheckPassedNotification = @"NetCheckPassedNotification";
NSString * const ScriptCompletedNotification = @"ScriptCompletedNotification";
NSString * const StatusUpdateNotification = @"StatusUpdateNotification";
NSString * const ReceiveStatusUpdateNotification = @"ReceiveStatusUpdateNotification";
NSString * const RequestStatusUpdateNotification = @"RequestStatusUpdateNotification";
// Script Notifications
NSString * const CriticalScriptFailureNotification = @"CriticalScriptFailureNotification";

NSString * const TotalFailureNotification = @"TotalFailureNotification";
NSString * const RecoveredFailureNotification = @"RecoveredFailureNotification";

// NSTask constants
NSString * const TaskPassed = @"Passed";
NSString * const TaskWarning = @"Warning";
NSString * const TaskCritical = @"Critical";

NSString * const UserPictureInvalidOutput = @"74DBE8F9-BFCD-4CA1-98DC-FC89CCE41439";



@end
