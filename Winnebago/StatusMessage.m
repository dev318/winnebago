//
//  StatusMessage.m
//	PasswordUtility
//
//  Created by Zack Smith on 7/19/11.
//  Copyright 2011 318. All rights reserved.
//

#import "StatusMessage.h"
#import "Constants.h"


@implementation StatusMessage


# pragma mark -
# pragma mark Method Overides
- (id)init
{	
	[super init];
	[self readInSettings];
	
	NSLog(@"StatusMessage Window did load");
	myInstallProgressFile = [settings objectForKey:@"installProgressFile"];
	myInstallProgressTxt = [settings objectForKey:@"installProgressTxt"];
	myInstallPhaseTxt = [settings objectForKey:@"installPhaseTxt"];
	
	[self removePreviousFiles ];
	// Activate the application
	[NSApp activateIgnoringOtherApps:YES];
	// Start the Progress Bar
	[ self startUserProgressIndicator];
	// Create our timer
	updateProgressBarTime = [[NSTimer scheduledTimerWithTimeInterval:1
															  target:self
															selector:@selector(readInstallProgress)
															userInfo:nil
															 repeats:YES]retain];
	[ updateProgressBarTime fire];
	return self;
}



-(void)dealloc 
{ 
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc]; 
}


- (void)readInSettings 
{ 	
	mainBundle = [NSBundle bundleForClass:[self class]];
	NSString *settingsPath = [mainBundle pathForResource:SettingsFileResourceID ofType:@"plist"];
	settings = [[NSDictionary alloc] initWithContentsOfFile:settingsPath];
	debugEnabled = [[settings objectForKey:@"debugEnabled"] boolValue];
}


-(void)removePreviousFiles{
	// Remove any previous txt at run time.
	[myFileManager removeItemAtPath:myInstallPhaseTxt error:NULL];
	[myFileManager removeItemAtPath:myInstallProgressTxt error:NULL];
}


-(void)sleepNow{
	[NSThread sleepForTimeInterval:1.0f];
}


# pragma mark Progress Bar Interactions
-(void)startUserProgressIndicator
{
	[userProgressBar setUsesThreadedAnimation:YES];
	[userProgressBar performSelectorOnMainThread:@selector(startAnimation:)
									  withObject:self
								   waitUntilDone:false];
}

-(void)stopUserProgressIndicator
{
	[userProgressBar performSelectorOnMainThread:@selector(stopAnimation:)
									  withObject:self
								   waitUntilDone:false];
}


-(void)readInstallProgress
{
	//if(debugEnabled)NSLog(@"Reading install progress...");
	[self updateProgressBar];
	[self updateStatusTxt];
	[self updatePhaseTxt];
	
}

-(void)updatePhaseTxt
{
	NSError *error;
	NSString *myCurrentPhaseTxt = [NSString stringWithContentsOfFile:myInstallPhaseTxt
															encoding:NSUTF8StringEncoding
															   error:&error];
	[ userProgressBar startAnimation:self];
	if (myCurrentPhaseTxt == nil)
	{
		//[ currentStatus setStringValue:@"Please Wait..."];
	}
	else
	{
		NSArray *myCurrentPhaseLines = [myCurrentPhaseTxt componentsSeparatedByString:@"\n"];		
		NSString *myCurrentPhaseLine = [myCurrentPhaseLines objectAtIndex:
										[myCurrentPhaseLines count] - 2 ];
		[ currentPhase setStringValue:myCurrentPhaseLine];
	}
}
-(void)updateStatusTxt
{
	NSError *error;
	NSString *myCurrentProgressTxt = [NSString stringWithContentsOfFile:myInstallProgressTxt
															   encoding:NSUTF8StringEncoding
																  error:&error];
	[ userProgressBar startAnimation:self];
	if (myCurrentProgressTxt == nil)
	{
		//[ currentStatus setStringValue:@"Please Wait..."];
	}
	else
	{
		[ currentStatus setStringValue:@"Setting up postupgrade actions..."];
		NSArray *myCurrentProgressLines = [myCurrentProgressTxt componentsSeparatedByString:@"\n"];		
		NSString *myCurrentProgressLine = [myCurrentProgressLines objectAtIndex:
										   [myCurrentProgressLines count] - 2 ];
		[ currentStatus setStringValue:myCurrentProgressLine];
	}
}
-(void)updateProgressBar
{
	NSError *error;
	NSString *myCurrentProgress = [NSString stringWithContentsOfFile:myInstallProgressFile
															encoding:NSUTF8StringEncoding
															   error:&error];
	[ userProgressBar startAnimation:self];
	if (myCurrentProgress == nil)
	{
		[ userProgressBar setIndeterminate:YES];
		//NSLog (@"%@", error);
	}
	else
	{
		NSArray *myCurrentProgressLines = [myCurrentProgress componentsSeparatedByString:@"\n"];
		[ userProgressBar setIndeterminate:NO];
		
		NSString *myCurrentProgressNumber = [myCurrentProgressLines objectAtIndex:
											 [myCurrentProgressLines count] -2 ];
		if ([myCurrentProgressNumber intValue] < 100) {
			[ userProgressBar setDoubleValue:[myCurrentProgressNumber doubleValue]];
		}
		else {
			[ userProgressBar setIndeterminate:YES];
		}
		
	}
}


-(void)repairStopped
{
	[ updateProgressBarTime invalidate];
}



@end
