//
//  Constants.h
//
//  Created by Zack Smith on 8/22/11.
//  Copyright 2011 318. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//Plugin Notifications
//Plugin Notifications
extern NSString * const PluginsHaveLoadedNotfication;
extern NSString * const NetCheckInProgressNotification;
extern NSString * const NetCheckFinishedNotification;
extern NSString * const NetCheckPassedNotification;
extern NSString * const SettingsFileResourceID;
extern NSString * const ScriptCompletedNotification;
extern NSString * const RequestStatusUpdateNotification;
extern NSString * const StatusUpdateNotification;
extern NSString * const ReceiveStatusUpdateNotification;

// NSTask
extern NSString * const TaskPassed;
extern NSString * const TaskWarning;
extern NSString * const TaskCritical;

extern NSString * const UserPictureInvalidOutput;

//Scripts
extern NSString * const CriticalScriptFailureNotification;
extern NSString * const TotalFailureNotification;
extern NSString * const RecoveredFailureNotification;


@interface Constants : NSObject {

}

@end
