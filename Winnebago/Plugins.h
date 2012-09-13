//
//  Plugins.h
//  PasswordUtility
//
//  Created by Zack Smith on 8/15/11.
//  Copyright 2011 318. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Constants.h"


@interface Plugins : NSObject {
	// IBOutlets
	IBOutlet NSMenu *statusMenu;
	IBOutlet NSMenuItem *latestUpdatesHeaderStatusItem;
	// Global status arrays
	NSMutableArray *globalStatusArray;
	
	// Settings & Bundle
	NSBundle *mainBundle;
	NSDictionary *settings;
	
	// NSTask
	NSMutableArray *configScriptArguments;

	BOOL scriptIsRunning;
	BOOL debugEnabled;
	BOOL criticalFailure;
	NSString *userName;
	NSString *oldPassword;
	NSString *newPassword;
	NSString *oldUserName;
	
}
//void
- (void)readInSettings ;
- (void)waitForLastScriptToFinish;
- (void)addConfigScriptArguments;
- (void)runPluginScripts:(id)sender;
- (void)setFailedEndStatusFromScript:(NSDictionary *)scriptDictionary
						   withError:(NSString *)scriptOutput
						withExitCode:(int)exitStatus
						  controller:(id)sender;

-(void)setStatus:(NSString *)scriptStatus
	   withTitle:(NSString *)scriptTitle
	   withImage:(NSString *)scriptImage
	  withReason:(NSString *)scriptReason
	  withMetric:(NSString *)metric 
	  withOutput:(NSString *)scriptOutput;

-(void)setEndStatusFromScript:(NSDictionary *)scriptDictionary
				   withOutPut:scriptOutput
				   controller:(id)sender;
// BOOL
- (BOOL)runScript:(NSDictionary *)scriptDictionary
	   controller:(id)sender
	 scriptNumber:(int)n;

- (void)launchPrivilegedScript:(NSDictionary *)scriptDictionary
				  withUserName:(NSString *)user
				  withPassword:(NSString *)pass
				 withArguments:(NSArray *)args
				  scriptNumber:(int)n;

-(void)setMyStatus:(NSString *)myStatus
		 withTitle:(NSString *)myTitle
	setDescription:(NSString *)myDescription
		withReason:(NSString *)reason
		withMetric:(NSString *)metric
		 withImage:(NSString *)myImage
		withOutput:(NSString *)myOutput;

@property (retain) NSString* userName;
@property (retain) NSString* oldPassword;
@property (retain) NSString* newPassword;
@property (retain) NSString* oldUserName;


@end