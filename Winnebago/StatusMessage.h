//
//  StatusMessage.h
//  PasswordUtility
//
//  Created by Zack Smith on 7/19/11.
//  Copyright 2011 318. All rights reserved.
//
// Removed makeWindowFullScreen

#import <Cocoa/Cocoa.h>
#import "Constants.h"


@interface StatusMessage : NSWindowController {
	NSFileManager *myFileManager;
	NSTimer *updateProgressBarTime;
	NSString *myInstallProgressFile;
	NSString *myInstallProgressTxt;
	NSString *myInstallPhaseTxt;
	NSString *InstallProgressTxt;
	IBOutlet NSProgressIndicator *userProgressBar;
	IBOutlet NSWindow *window;
	IBOutlet NSTextField *currentStatus;
	IBOutlet NSTextField *currentPhase;
	
	NSBundle *mainBundle;
	NSDictionary *settings;
	BOOL debugEnabled;
}
- (void)readInSettings ;
- (void) startUserProgressIndicator;
- (void) stopUserProgressIndicator;
- (void) sleepNow;
- (void) readInstallProgress;
- (void) updateProgressBar;
- (void) updateStatusTxt;
- (void) updatePhaseTxt;
- (void)removePreviousFiles;
- (void)repairStopped;

@end
