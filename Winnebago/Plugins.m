//
//  Plugins.m
//  PasswordUtility
//
//  Created by Zack Smith on 8/15/11.
//  Copyright 2011 318. All rights reserved.
//
// Removed updatePluginMenus

#import "Plugins.h"
#import "Constants.h"



@implementation Plugins

// Synthesize our property methods i.e. self.userName = @"foo"

@synthesize userName;
@synthesize oldUserName;
@synthesize oldPassword;
@synthesize newPassword;

#pragma mark Method Overrides
-(id)init
{
    [ super init];
	[ self readInSettings];
	if(debugEnabled)NSLog(@"Init OK Plugins Controller Initialized");

	// Init our ivar for Global Status Array
	if (!globalStatusArray) {
		globalStatusArray = [[ NSMutableArray alloc] init];
	}
    return self;
}

- (void)readInSettings 
{ 	
	mainBundle = [NSBundle bundleForClass:[self class]];
	NSString *settingsPath = [mainBundle pathForResource:SettingsFileResourceID
												  ofType:@"plist"];
	settings = [[NSDictionary alloc] initWithContentsOfFile:settingsPath];
	debugEnabled = [[settings objectForKey:@"debugEnabled"] boolValue];
}



-(void)dealloc 
{ 
	// Remove observer for window close
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	//[self.globalStatusArray release];
	[super dealloc]; 
}

#pragma mark Class Methods

-(void)runPluginScripts:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	if(debugEnabled) NSLog(@"Running Plugin Scripts...");
	// Add the UserName , Password, and Old Password as -u -p -o to an Array
	[self addConfigScriptArguments];
	
	NSDictionary * scriptPlugins = [ settings objectForKey:@"scriptPlugins"];
	
	// Grab the dictionary for nonPrivilegedScripts
	NSDictionary * mainRunLoopScripts = [ scriptPlugins objectForKey:@"mainRunLoopScripts"];
	
	// Enumerate our Scripts
	for(NSString *header in mainRunLoopScripts){
		NSDictionary *scriptHeader = [mainRunLoopScripts objectForKey:header];
		
		// Grab the Header Menu Item Title
		NSString *headerTitle = [scriptHeader objectForKey:@"headerTitle"];
		if(debugEnabled)NSLog(@"Found Script Title: %@",headerTitle);
		
		NSArray * itemScripts = [scriptHeader objectForKey:@"itemScripts"];
		int n = 1;
		// Enumerate through the items array to add items below our header
		for (id scriptDictionary in itemScripts) {
			if(debugEnabled) NSLog(@"Running script: %d",n);
			[ self runScript:scriptDictionary
				  controller:sender 
				scriptNumber:n];
			// Catch our critical failures and stop loop
			if (criticalFailure) {
				break;
			}
			n = n+ 1;
		 }		
	}
	
	// Notifiy our observers that plugins have loaded
	/*if(debugEnabled)  NSLog(@"Notifying the Application that script plugins have loaded");
	[[NSNotificationCenter defaultCenter]
	 postNotificationName:PluginsHaveLoadedNotfication
	 object:self];*/
	[pool release];
	
}


- (void) addConfigScriptArguments
{
	configScriptArguments = [[NSMutableArray alloc] init];
	// -u
	[ configScriptArguments addObject:@"-u"];
	if(debugEnabled) NSLog(@"DEBUG: Adding userName: %@",self.userName);
	[ configScriptArguments addObject:self.userName];
	// -p
	[ configScriptArguments addObject:@"-p"];
	if(debugEnabled) NSLog(@"DEBUG:  newPassword: %@",self.newPassword);
	[ configScriptArguments addObject:self.newPassword];
	//-o
	[ configScriptArguments addObject:@"-o"];
	if(debugEnabled) NSLog(@"DEBUG: oldPassword: %@",self.oldPassword);
	[ configScriptArguments addObject:self.oldPassword];
	
	[ configScriptArguments addObject:@"-l"];
	if(debugEnabled) NSLog(@"DEBUG: oldUserName: %@",self.oldUserName);
	[ configScriptArguments addObject:self.oldUserName];
	if(debugEnabled) NSLog(@"DEBUG: Generated configuration Script Arguments: %@",configScriptArguments);


}


- (BOOL)runScript:(NSDictionary *)scriptDictionary
	   controller:(id)sender
	 scriptNumber:(int)n

{	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	// Check for any scripts running at the moment
	[self waitForLastScriptToFinish];
	// Take control of the run lock
	scriptIsRunning = YES;
	
	NSString *scriptPath = [scriptDictionary objectForKey:@"scriptPath"];
	
	NSString *scriptExtention = [scriptDictionary objectForKey:@"scriptExtention"];
	
	if ([[scriptDictionary objectForKey:@"scriptIsInBundle"] boolValue]){
		scriptPath = [mainBundle pathForResource:scriptPath ofType:scriptExtention];
		if (!scriptPath) {
			if(debugEnabled)NSLog(@" No Script path found");
			
		}
		else {
			if(debugEnabled) NSLog(@"Found script path:%@",scriptPath);
		}
		
	}
	// Validate script exits and is executable
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath:scriptPath]){
		if(debugEnabled) NSLog(@"Script exists at path:%@",scriptPath);
	}
	else {
		NSException    *anException;
		NSLog(@"Script does NOT exist at path:%@",scriptPath);
		NSString *aReason = [ NSString stringWithFormat:@"Script missing: %@",scriptPath];
		anException = [NSException exceptionWithName:@"Missing Script" 
											  reason:aReason
											userInfo:nil];
		return NO;
	}
	// Check script is executable
	if ([[NSFileManager defaultManager]isExecutableFileAtPath:scriptPath]) {
		if(debugEnabled)NSLog(@"Validated script is executable");
		
	}
	else {
		NSException    *anException;
		NSLog(@"Script is NOT executable at path:%@",scriptPath);
		NSString *aReason = [ NSString stringWithFormat:@"Script not executable: %@",scriptPath];
		anException = [NSException exceptionWithName:@"Script Attributes" 
											  reason:aReason
											userInfo:nil];
		return NO;
	}
	
	// Run the Task - Z1: Needs to be broken out
	
	NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath: scriptPath];
	
	
	
	if(debugEnabled)NSLog(@"Passing arguments to task: %@",configScriptArguments);
	[task setArguments: configScriptArguments];
	
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
	//Set to help with Xcode debug log issues
	[task setStandardInput:[NSPipe pipe]];
	
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    [task launch];
    NSData *data;
    data = [file readDataToEndOfFile];
	
    NSString *scriptOutput;
	[task waitUntilExit];
	
	// Notification that the current script is complete
	
	if(debugEnabled) NSLog(@"DEBUG: Notifying of script %d completion",n);
	
	NSMutableDictionary *userinfo = [[NSMutableDictionary alloc] init];
	[ userinfo setValue:[NSNumber numberWithInt:n] forKey:@"currentScriptNumber"];
	[[NSNotificationCenter defaultCenter]
	 postNotificationName:ScriptCompletedNotification
	 object:self
	 userInfo:userinfo];
	
    scriptOutput = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
	if (!scriptOutput) {
		scriptOutput = @"Error";
	}
	int status = [task terminationStatus];
	scriptIsRunning = NO;
	[pool release];
	if ( status > 0 ){
		[self setFailedEndStatusFromScript:scriptDictionary
								 withError:scriptOutput
							  withExitCode:status
								controller:sender];
		return NO;

	}
	else {
	// exit 0
	[self setEndStatusFromScript:scriptDictionary
					  withOutPut:scriptOutput
					  controller:sender];
		return YES;
	}
	[pool drain];
	
}

- (void)launchPrivilegedScript:(NSDictionary *)scriptDictionary
				 withUserName:(NSString *)user
				 withPassword:(NSString *)pass
				 withArguments:(NSArray *)args
				  scriptNumber:(int)n
{	
	// This was the Apple Script Methodology not working in 10.7 with Centrify
	/*
	// Create a pool so we don't leak on our NSThread
	
	NSString *scriptPath = [scriptDictionary objectForKey:@"scriptPath"];
	
	NSString *scriptExtention = [scriptDictionary objectForKey:@"scriptExtention"];
	
	if ([[scriptDictionary objectForKey:@"scriptIsInBundle"] boolValue]){
		scriptPath = [mainBundle pathForResource:scriptPath ofType:scriptExtention];
		if (!scriptPath) {
			if(debugEnabled) NSLog(@"DEBUG: No Script path found ");
		}
		else {
			if(debugEnabled) NSLog(@"DEBUG: Found script path:%@",scriptPath);
		}
		
	}
	// Validate script exits and is executable
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath:scriptPath]){
		if(debugEnabled) NSLog(@"DEBUG: Script exists at path:%@",scriptPath);
	}
	else {
		NSException    *anException;
		NSLog(@"ERROR: Script does NOT exist at path:%@",scriptPath);
		NSString *aReason = [ NSString stringWithFormat:@"Script missing: %@",scriptPath];
		anException = [NSException exceptionWithName:@"Missing Script" 
											  reason:aReason
											userInfo:nil];
		return;
	}
	// Check script is executable
	if ([[NSFileManager defaultManager]isExecutableFileAtPath:scriptPath]) {
		NSLog(@"Validated script is executable");
		
	}
	else {
		NSException    *anException;
		NSLog(@"Script is NOT executable at path:%@",scriptPath);
		NSString *aReason = [ NSString stringWithFormat:@"Script not executable: %@",scriptPath];
		anException = [NSException exceptionWithName:@"Script Attributes" 
											  reason:aReason
											userInfo:nil];
		return;
	}
	NSString * argumentsString = @"";
	NSString *argument;
	for (NSString *arg in args) {
		if(debugEnabled) NSLog(@"Processing argument: %@",arg);
		if(debugEnabled) NSLog(@"Current arg count: %d",[args count]);
		if(debugEnabled) NSLog(@"Current index of object: %d",[args indexOfObjectIdenticalTo:arg]);
		if ([args count] == [args indexOfObjectIdenticalTo:arg] +1) {
			// Don't add the space if we are the last element in the array
			if(debugEnabled) NSLog(@"No arguments remain:");

			argument = [NSString stringWithFormat:@"\"%@\"",arg];
			if(debugEnabled) NSLog(@"Generated AppleScript Argument: %@",argument);
		}
		else {
			if(debugEnabled) NSLog(@"Multiple arguments remain");
			// Add the leading space if we are not the last element in the array
			argument = [NSString stringWithFormat:@"\"%@\" & space & ",arg];
			if(debugEnabled) NSLog(@"Generated AppleScript Argument: %@",argument);
		}

		argumentsString = [ argumentsString stringByAppendingString:argument];
	}
	if(debugEnabled) NSLog(@"Generated argument string:%@",argumentsString);
	
	
	
	NSDictionary* errorDict;
	NSAppleEventDescriptor* returnDescriptor = NULL;
	NSString * scriptSource = [NSString stringWithFormat:
							   @"\
							   do shell script (quoted form of \"%@\") & space & %@ user name \"%@\" password \"%@\" with administrator privileges\n\
							   ",scriptPath,argumentsString,user,pass];
	
	if(debugEnabled) NSLog(@"Generated AppleScript source: %@",scriptSource);
	NSAppleScript* scriptObject = [[NSAppleScript alloc] initWithSource:scriptSource];
	returnDescriptor = [scriptObject executeAndReturnError: &errorDict];
	
	
	if(debugEnabled) NSLog(@"DEBUG: Notifying of script %d completion",n);
	
	NSMutableDictionary *userinfo = [[NSMutableDictionary alloc] init];
	[ userinfo setValue:[NSNumber numberWithInt:n] forKey:@"currentScriptNumber"];
	[[NSNotificationCenter defaultCenter]
	 postNotificationName:ScriptCompletedNotification
	 object:self
	 userInfo:userinfo];
	
	[scriptObject release];(*/
	
}


-(void)setFailedEndStatusFromScript:(NSDictionary *)scriptDictionary
						  withError:(NSString *)scriptOutput
					   withExitCode:(int)exitStatus
						 controller:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString *scriptStatus;
	NSString *scriptFailedTitle;
	NSString *scriptFailedDescription;
	
	// Check for our warning
	if (exitStatus == 1) {
		scriptStatus = TaskWarning;
		// Use our warning text
		scriptFailedTitle = [scriptDictionary valueForKey:@"scriptWarningTitle"];
		scriptFailedDescription = [scriptDictionary valueForKey:@"scriptWarningDescription"];

		if(debugEnabled)NSLog(@"Found Script Failed message: %@",scriptFailedTitle);
	}
	
	// Check for critical failure
	if (exitStatus > 1) {
		// If the status is greater then 1 then set the task as critical
		scriptStatus = TaskCritical;
		
		[[NSNotificationCenter defaultCenter]
		 postNotificationName:CriticalScriptFailureNotification
		 object:self];
		criticalFailure = YES;
		
		NSString *exitStatusKey = [ NSString stringWithFormat:@"%d",exitStatus ];
		if(debugEnabled)NSLog(@"Found exit status:%@",exitStatusKey);
		// Read in our exit status info from keys
		NSDictionary *exitCodes = [ scriptDictionary objectForKey:@"exitCodes" ];
		NSDictionary *exitCode	= [ exitCodes objectForKey:exitStatusKey ];
		// Red status for exit codes that are greater then 1
		if (exitStatus >= 192){
			if(debugEnabled) NSLog(@"Exit status was greater then or equal 192. Was (%d)",exitStatus);
		}
		
		// Grab Our Specific Error code
		scriptFailedTitle = [ exitCode objectForKey:@"scriptFailedTitle"];
		scriptFailedDescription = [exitCode objectForKey:@"scriptFailedDescription"];

		// Just in case we forgot to add an exit code string
		if (!exitCode) {
			scriptFailedTitle = [ scriptDictionary objectForKey:@"scriptFailedTitle"];
			scriptFailedDescription = [scriptDictionary objectForKey:@"scriptFailedDescription"];
		}
		
	}
	NSString *scriptImage = [scriptDictionary objectForKey:@"scriptImage"];
	NSString *scriptCode = [NSString stringWithFormat: @"%d", exitStatus];
	[self setStatus:scriptStatus
		  withTitle:scriptFailedTitle
		  withImage:scriptImage
		 withReason:scriptFailedDescription
		 withMetric:scriptCode
		 withOutput:scriptOutput];
	[pool release];

}

-(void)setStatus:(NSString *)scriptStatus
	   withTitle:(NSString *)scriptTitle
	   withImage:(NSString *)scriptImage
	  withReason:(NSString *)scriptReason
	  withMetric:(NSString *)scriptMetric
	  withOutput:(NSString *)scriptOutput
{
	
	[self setMyStatus:scriptStatus
			withTitle:scriptTitle
	   setDescription:scriptReason
		   withReason:scriptReason
		   withMetric:scriptMetric
			withImage:scriptImage
		   withOutput:scriptOutput];
	if(debugEnabled)NSLog(@"Finished script: %@",scriptTitle);
}

-(void)waitForLastScriptToFinish
{
	while (scriptIsRunning) {
		[NSThread sleepForTimeInterval:0.5f];
		if(debugEnabled)NSLog(@"Waiting for last script to run...");
	}
}


-(void)setEndStatusFromScript:(NSDictionary *)scriptDictionary
				   withOutPut:scriptOutput
					controller:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	// Check if we were passed an empty value.
	NSString *scriptTitle;
	/*if (![scriptOutput isEqualToString:@""]) {
		scriptTitle = scriptOutput;
	}
	else {
		scriptTitle = [scriptDictionary objectForKey:@"scriptEndTitle"];
	}*/
	scriptTitle = [scriptDictionary objectForKey:@"scriptEndTitle"];
	NSString *scriptDescription = [scriptDictionary objectForKey:@"scriptEndDescription"];
	NSString *scriptImage = [scriptDictionary objectForKey:@"scriptImage"];
	NSString *scriptCode = [NSString stringWithFormat: @"%d", 0];

	if(debugEnabled)NSLog(@"Successful Script run:%@",scriptTitle);
	if(debugEnabled)NSLog(@"Successful Script Description:%@",scriptDescription);
	
	[self setStatus:TaskPassed
		  withTitle:scriptTitle
		  withImage:scriptImage
		 withReason:scriptDescription
		 withMetric:scriptCode
		 withOutput:scriptOutput];
	
	if(debugEnabled) NSLog(@"%@: Shell Script exited 0",scriptTitle);
	[pool release];
}

-(void)setMyStatus:(NSString *)myStatus
		 withTitle:(NSString *)myTitle
	setDescription:(NSString *)myDescription
		withReason:(NSString *)reason
		withMetric:(NSString *)metric
		 withImage:(NSString *)myImage
		withOutput:(NSString *)myOutput
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	if(debugEnabled)NSLog(@"Status Update");
	if(debugEnabled)NSLog(@"Status myStatus: %@",myStatus);
	if(debugEnabled)NSLog(@"Status myDescription: %@",myDescription);
	if(debugEnabled)NSLog(@"Status reason: %@",reason);
	if(debugEnabled)NSLog(@"Status metric: %@",metric);

	// Create a temp status dictionary that we can mutate
	NSMutableDictionary * myStatusDictionary = [[ NSMutableDictionary alloc] init];
	// Add the passed information
	[ myStatusDictionary setObject:myStatus forKey:@"status"];
	[ myStatusDictionary setObject:myDescription forKey:@"discription"];
	[ myStatusDictionary setObject:reason forKey:@"reason"];
	[ myStatusDictionary setObject:metric forKey:@"metric"];
	[ myStatusDictionary setObject:myImage forKey:@"image"];
	[ myStatusDictionary setObject:myTitle forKey:@"title"];
	[ myStatusDictionary setObject:myOutput forKey:@"output"];

	// Add our status Dictionary to the Global Status Array
	[globalStatusArray addObject:myStatusDictionary];
	
	// Let objects know the Global Status is being updated
	NSMutableDictionary *globalStatusUpdate = [[NSMutableDictionary alloc] init];
	
	[ globalStatusUpdate setValue:globalStatusArray forKey:@"globalStatusArray"];

	// Pass the mutated Data to our NSTable
	[[NSNotificationCenter defaultCenter]
	 postNotificationName:StatusUpdateNotification
	 object:self
	 userInfo:globalStatusUpdate];
	[pool release];
}

@end
