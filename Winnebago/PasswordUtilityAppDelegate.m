//
//  PasswordUtilityAppDelegate.m
//
//  Created by Zack Smith on 11/16/11.
//  Copyright 2011 318 All rights reserved.
//

#import "PasswordUtilityAppDelegate.h"
#import "Plugins.h"
#import "GlobalStatus.h"
#import "Constants.h"
#import "FullScreenController.h"
#import "FullscreenWindow.h"

@implementation PasswordUtilityAppDelegate

@synthesize window;
@synthesize oldPassword;
@synthesize newUserName;
@synthesize newPassword;
@synthesize oldUserName;
@synthesize webView;
@synthesize netCheckRunning;
@synthesize requiredToRun;
@synthesize daysRemaining;
// Text Properties
@synthesize processCompleteText;
@synthesize networkCheckText;
@synthesize revertText;
@synthesize failureText;

# pragma mark -
# pragma mark Method Overrides
# pragma mark -

-(id)init
{
    // Super init
	[ super init];

	if(debugEnabled)NSLog(@"Init OK App Delegate Controller Initialized");
	setuid(0);

	// Read in our Settings
	[ self readInSettings];
	// Register for Notifications
	//NetCheckInProgressNotification
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(networkCheckInProgress) 
                                                 name:NetCheckInProgressNotification
                                               object:nil];
	//NetCheckFinishedNotification
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(networkCheckFinished) 
                                                 name:NetCheckFinishedNotification
                                               object:nil];
	//NetCheckPassedNotification
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(closeNetworkCheckPanel) 
                                                 name:NetCheckPassedNotification
											   object:nil];
	
	//ScriptCompletedNotification
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadLevelIndicator:) 
                                                 name:ScriptCompletedNotification
                                               object:nil];
	
	//CriticalScriptFailureNotification 
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(criticalFailure:) 
                                                 name:CriticalScriptFailureNotification
                                               object:nil];
	
	//RecoveredFailureNotification
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(recoveredFailure:) 
                                                 name:RecoveredFailureNotification
                                               object:nil];
	//TotalFailureNotification 
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(totalFailure:) 
                                                 name:TotalFailureNotification
                                               object:nil];
	
	// Init our controller
	if (!globalStatusController) {
		globalStatusController = [[GlobalStatus alloc] init];
	}
	// And Return
	if (!self) return nil;
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
	// Stop Lion from saving state
	if([standardDefaults objectForKey: @"ApplePersistenceIgnoreState"] == nil)
		[standardDefaults setBool: YES forKey:@"ApplePersistenceIgnoreState"];
	[ self bringToFront];
	if ([[settings objectForKey:@"showProceedDialog"] boolValue]) {
		// Activate Our Application
		[NSApp arrangeInFront:self];
		[NSApp activateIgnoringOtherApps:YES];
		[self displayProceedPanel];
	}
	self.daysRemaining = [self checkRunDay];
	[self saveLastRunDate];
	if (self.requiredToRun) {
		//[self makeWindowFullScreen];
	}
}

- (void)awakeFromNib {
	
	// Set the we need a Window Resize
	windowNeedsResize = YES;
	[self closeAllBoxes];
	// Start By Expanding Old Progress Bar
	[mainButton setAction:@selector(expandOldPasswordBox:)];
	[userPictureView setHidden:YES];
	
	self.oldUserName = [self checkUserScript];
	
	NSLog(@"DEBUG: Found old username: %@",self.oldUserName);
	
	// Check if we were able to guess UNIXID
	if (![self.oldUserName length] == 0) {
		/*[unixIdField setStringValue:self.oldUserName];
		if ([[settings objectForKey:@"alwaysChooseMobile"] boolValue]) {
			[unixIdField setEnabled:NO];
		}*/

		[mainButton setEnabled:YES];
	}
	else {
		[mainButton setEnabled:NO];
	}


}
# pragma mark -
# pragma mark Delegate Methods
# pragma mark -

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}


- (void)windowWillClose:(NSNotification *)aNotification {
  // Quit the app when the window closes
  [self quit];


}

# pragma mark -
# pragma mark Methods
# pragma mark -


- (void)readInSettings 
{ 	
	mainBundle = [NSBundle bundleForClass:[self class]];
	NSString *settingsPath = [mainBundle pathForResource:SettingsFileResourceID
												  ofType:@"plist"];
	
	NSDictionary *defaults = [[NSDictionary alloc] initWithContentsOfFile:settingsPath];
	
	// Register our defaults
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
	
	settings = [NSUserDefaults standardUserDefaults];
	
	debugEnabled = [[settings objectForKey:@"debugEnabled"] boolValue];
	
	
	// Text Properties
	self.processCompleteText = [settings objectForKey:@"processCompleteText"];
	self.networkCheckText = [settings objectForKey:@"networkCheckText"];
	self.revertText = [settings objectForKey:@"revertText"];
	self.failureText = [settings objectForKey:@"failureText"];
}


- (void)criticalFailure:(NSNotification *)aNotification
{
	// This kicks off the revert script
	[NSThread detachNewThreadSelector:@selector(revertChangesScript)
							 toTarget:self
						   withObject:nil];
}
- (void)recoveredFailure:(NSNotification *)aNotification
{
	[self performSelectorOnMainThread:@selector(displayRevertPanel)
						   withObject:nil
						waitUntilDone:FALSE];
}
- (void)totalFailure:(NSNotification *)aNotification
{
	[self closeStatusMessagePanel];
	[self displayTotalFailurePanel];	
}


- (void)proceedPanelDidEnd
{
	// Show the panel either way
	[self displayNetworkPanel];
	// Show the progress panel
	if ([[settings objectForKey:@"checkNetwork"] boolValue]) {
		// Start our network Script
		[NSThread detachNewThreadSelector:@selector(netCheckScript)
								 toTarget:self
							   withObject:nil];
	}
	else {
		// Fake a good a reult if we are not true
		[[NSNotificationCenter defaultCenter]
		 postNotificationName:NetCheckPassedNotification
		 object:self];
	}

	
}


-(IBAction)focusOnVerifyField:(id)sender
{
	[verifyNewPasswordField becomeFirstResponder];
}

- (void)controlTextDidChange:(NSNotification *)nd
{
	if (![[unixIdField stringValue] length] == 0 ) {
		[mainButton setEnabled:YES];
	}
}

# pragma mark -
# pragma mark NSProgressIndicator  - mainProgressIndicator
# pragma mark -

-(void)startUnixIdProgressIndicator
{
	[ unixIdProgressIndicator startAnimation:self];
}

-(void)stopUnixIdProgressIndicator
{
	[ unixIdProgressIndicator stopAnimation:self];
}

-(void)startMainProgressIndicator
{
	[ mainProgressIndicator startAnimation:self];

}

-(void)stopMainProgressIndicator
{

	[ mainProgressIndicator stopAnimation:self];
	
}

-(void)stopNewPasswordProgressIndicator
{
	
	[ newPasswordProgressIndicator stopAnimation:self];
	
}
-(void)startNewPasswordProgressIndicator
{
	
	[ newPasswordProgressIndicator startAnimation:self];
	
}

-(void)stopOldPasswordProgressIndicator
{
	
	[ oldPasswordProgressIndicator stopAnimation:self];
	
}
-(void)startOldPasswordProgressIndicator
{
	
	[ oldPasswordProgressIndicator startAnimation:self];
	
}


-(void)stopNetProgressIndicator
{
	
	[ netProgressIndicator stopAnimation:self];
	
}
-(void)startNetProgressIndicator
{
	[ netProgressIndicator setIndeterminate:YES];
	[ netProgressIndicator startAnimation:self];
	
}


#pragma mark -



-(NSString *)checkUserScript
{
	NSTask       *task;
	task = [[NSTask alloc] init];

	
	NSData *data;
	// Start
	NSPipe *pipe = [NSPipe pipe];
	
	//_fileHandle = [pipe fileHandleForReading];
	//[_fileHandle readInBackgroundAndNotify];
	// Grab both our system profile outputs
	NSString *script = [mainBundle pathForResource:@"checkUser"
													ofType:@"sh"];
	[task setLaunchPath:script];
	[task setArguments:[NSArray arrayWithObjects:nil]];
	[task setStandardOutput: pipe];
	//Set to help with Xcode debug log issues
	[task setStandardInput:[NSPipe pipe]];
	[task setStandardError: pipe];
	[task launch];
	//NSData *readData;
	NSFileHandle *file;
	file = [pipe fileHandleForReading];
	data = [file readDataToEndOfFile];
	// We now have our full results in a NSString
	NSString *text = [[NSString alloc] initWithData:data 
										   encoding:NSASCIIStringEncoding];
	
	NSArray *components = [text componentsSeparatedByString:@"<result>"];
	NSString *returnValue;
	if ([components count] > 1) {
		NSString *afterOpenBracket = [components objectAtIndex:1];
		components = [afterOpenBracket componentsSeparatedByString:@"</result>"];
		if ([components count] > 1) {
		returnValue = [components objectAtIndex:0];	
		}
		else {
			returnValue = @"";
		}

	}
	else {
		returnValue = @"";
	}

	
	if(debugEnabled)NSLog(@"Found Guess UserName: (%@)",returnValue);
	return returnValue;
}

-(void)hideMainBoxContent:(BOOL)hide
{
	[alertIcon setHidden:hide];
	[alertTextField setHidden:hide];
	[openVPNButton setHidden:hide];
	[notNowButton setHidden:hide];
	[tryAgainButton setHidden:hide];
}

-(void)revertChangesScript
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSTask       *task;
	task = [[NSTask alloc] init];
	
	NSData *data;
	// Start
	NSPipe *pipe = [NSPipe pipe];
	
	//_fileHandle = [pipe fileHandleForReading];
	//[_fileHandle readInBackgroundAndNotify];
	// Grab both our system profile outputs
	NSString *script = [mainBundle pathForResource:@"revertChanges"
											ofType:@"sh"];
	[task setLaunchPath:script];
	// Pass our new credentials to the script
	NSMutableArray *configScriptArguments;
	configScriptArguments = [[NSMutableArray alloc]
												 initWithObjects:@"-n",
												 self.newUserName,
												 @"-N",
												 self.newPassword,
												 @"-l",self.oldUserName,
												 @"-L",self.oldPassword,
												 nil];
	NSLog(@"DEBUG:%@",configScriptArguments);
		



	
	[task setArguments:configScriptArguments];
	 [task setStandardOutput: pipe];
	//Set to help with Xcode debug log issues
	[task setStandardInput:[NSPipe pipe]];
	[task setStandardError: pipe];
	[task launch];
	[task waitUntilExit];
	NSFileHandle *file;
	file = [pipe fileHandleForReading];
	data = [file readDataToEndOfFile];
	
	// Post Finished Notifications
	int exit = [task terminationStatus];
	
	[ pool release];
	if (exit == 0)
	{
		[[NSNotificationCenter defaultCenter]
		 postNotificationName:RecoveredFailureNotification
		 object:self];
		return;
	}
	[[NSNotificationCenter defaultCenter]
	 postNotificationName:TotalFailureNotification
	 object:self];
	return;
}

-(BOOL)checkLocalBindScript
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSTask       *task;
	task = [[NSTask alloc] init];	
	
	NSData *data;
	// Start
	NSPipe *pipe = [NSPipe pipe];
	
	//_fileHandle = [pipe fileHandleForReading];
	//[_fileHandle readInBackgroundAndNotify];
	// Grab both our system profile outputs
	NSString *script = [mainBundle pathForResource:@"checkLocalBind"
											ofType:@"sh"];
	[task setLaunchPath:script];
	// Pass our new credentials to the script
	if ([self.newPassword isEqualToString:self.oldPassword]) {
		if(debugEnabled)NSLog(@"Old and new passwords match or first run");
		[task setArguments:[NSArray arrayWithObjects:@"-u",self.newUserName,@"-p",self.newPassword,nil]];
		if(debugEnabled)NSLog(@"Added arguments: %@",[NSArray arrayWithObjects:@"-u",self.newUserName,@"-p",self.newPassword,nil]);
	}
	else{
		if(debugEnabled)NSLog(@"Old and new passwords mismatch");
		if (!self.oldPassword) {
			self.oldPassword = self.newPassword;
		}
		[task setArguments:[NSArray arrayWithObjects:@"-u",self.newUserName,@"-p",self.oldPassword,nil]];
		if(debugEnabled)NSLog(@"Added arguments: %@",[NSArray arrayWithObjects:@"-u",self.newUserName,@"-p",self.oldPassword,nil]);

	}

	[task setStandardOutput: pipe];
	//Set to help with Xcode debug log issues
	[task setStandardInput:[NSPipe pipe]];
	[task setStandardError: pipe];
	[task launch];
	[task waitUntilExit];
	NSFileHandle *file;
	file = [pipe fileHandleForReading];
	data = [file readDataToEndOfFile];
	
	NSString *text = [[NSString alloc] initWithData:data 
										   encoding:NSASCIIStringEncoding];
	
	//if(debugEnabled)NSLog(@"checkLocalBind returned the following: %@",text);
	

	
	// Post Finished Notifications
	int exit = [task terminationStatus];
	

	//newUserName
	[ pool release];
	if (exit == 0)
	{
		return YES;
	}
	else {
		
		return NO;
	}
	return NO;
}

-(BOOL)checkBatteryPower
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSTask       *task;
	task = [[NSTask alloc] init];	
	
	NSData *data;
	// Start
	NSPipe *pipe = [NSPipe pipe];
	
	//_fileHandle = [pipe fileHandleForReading];
	//[_fileHandle readInBackgroundAndNotify];
	// Grab both our system profile outputs
	NSString *script = [mainBundle pathForResource:@"checkBatt"
											ofType:@"sh"];
	[task setLaunchPath:script];
	[task setStandardOutput: pipe];
	//Set to help with Xcode debug log issues
	[task setStandardInput:[NSPipe pipe]];
	[task setStandardError: pipe];
	[task launch];
	[task waitUntilExit];
	NSFileHandle *file;
	file = [pipe fileHandleForReading];
	data = [file readDataToEndOfFile];
	
	NSString *text = [[NSString alloc] initWithData:data 
										   encoding:NSASCIIStringEncoding];
	
	//if(debugEnabled)NSLog(@"checkLocalBind returned the following: %@",text);
	
	
	
	// Post Finished Notifications
	int exit = [task terminationStatus];
	
	
	//newUserName
	[ pool release];
	if (exit == 0)
	{
		return YES;
	}
	else {
		
		return NO;
	}
	return NO;
}

-(BOOL)checkBindScript
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self startOldPasswordProgressIndicator];

	NSTask       *task;
	task = [[NSTask alloc] init];	
	
	NSData *data;
	// Start
	NSPipe *pipe = [NSPipe pipe];
	
	//_fileHandle = [pipe fileHandleForReading];
	//[_fileHandle readInBackgroundAndNotify];
	// Grab both our system profile outputs
	NSString *script = [mainBundle pathForResource:@"checkBind"
													ofType:@"sh"];
	[task setLaunchPath:script];
	// Pass our new credentials to the script
	[task setArguments:[NSArray arrayWithObjects:@"-u",
						self.newUserName,
						@"-p",
						self.newPassword,
						nil]];
	[task setStandardOutput: pipe];
	//Set to help with Xcode debug log issues
	[task setStandardInput:[NSPipe pipe]];
	[task setStandardError: pipe];
	[task launch];
	[task waitUntilExit];
	NSFileHandle *file;
	file = [pipe fileHandleForReading];
	data = [file readDataToEndOfFile];
	
	NSString *text = [[NSString alloc] initWithData:data 
										   encoding:NSASCIIStringEncoding];
	
	if(debugEnabled)NSLog(@"checkBind returned the following: %@",text);
	
	NSArray *components = [text componentsSeparatedByString:@"<result>"];
	NSString *returnValue;
	returnValue = [unixIdField stringValue];
	if ([components count] > 1) {
		NSString *afterOpenBracket = [components objectAtIndex:1];
		if(debugEnabled)NSLog(@"afterOpenBracket:%@",afterOpenBracket);
		components = [afterOpenBracket componentsSeparatedByString:@"</result>"];
		if(debugEnabled)NSLog(@"beforeOpenBracket:%@",components);
		if ([components count] > 0) {
			returnValue = [components objectAtIndex:0];
		}
	}



	
	if(debugEnabled)NSLog(@"Found Username: (%@)",returnValue);
	
	if (![[unixIdField stringValue] isEqualToString:returnValue]) {
		usernameChange = YES;
		self.newUserName = returnValue;
		[self displayChangePanel];
	}
	else {
		self.newUserName = [unixIdField stringValue];
	}


	// Post Finished Notifications
	int exit = [task terminationStatus];
	
	// BOOL Return value based on exit code
	[self startOldPasswordProgressIndicator];
	
	
	//newUserName
	[ pool release];
	if (exit == 0)
	{
		return YES;
	}
	else {

		return NO;
	}
	return NO;
}


-(BOOL)netCheckScript
{
	if(debugEnabled)NSLog(@"DEBUG: Running the netCheckScript");
	
	// For our progress bar
	self.netCheckRunning = YES;
	
	NSTask *task;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	// Notify panel to start showing progress bar
	
	[[NSNotificationCenter defaultCenter]
	 postNotificationName:NetCheckInProgressNotification
	 object:self];
	
	task = [[NSTask alloc] init];
	
	NSData *data;
	// Start
	NSPipe *pipe = [NSPipe pipe];
	
	//_fileHandle = [pipe fileHandleForReading];
	//[_fileHandle readInBackgroundAndNotify];
	// Grab both our system profile outputs
	NSString *getUserPicture = [mainBundle pathForResource:@"netCheck"
													ofType:@"sh"];
	[task setLaunchPath:getUserPicture];
	[task setArguments:[NSArray arrayWithObjects:nil]];
	[task setStandardOutput: pipe];
	//Set to help with Xcode debug log issues
	[task setStandardInput:[NSPipe pipe]];
	[task setStandardError: pipe];
	[task launch];
	//NSData *readData;
	NSFileHandle *file;
	file = [pipe fileHandleForReading];
	data = [file readDataToEndOfFile];
	[task waitUntilExit];
	
	// We now have our full results in a NSString
	NSString *text = [[NSString alloc] initWithData:data 
										   encoding:NSASCIIStringEncoding];
	if(debugEnabled)NSLog(@"Network Script Ran (%@)",text);
	
	// Post Finished Notifications
	int exit = [task terminationStatus];
	
	if(debugEnabled)NSLog(@"Network Exit code (%d)",exit);

	// For our progress bar
	self.netCheckRunning = NO;

	[ pool release];
	// BOOL Return value based on exit code
	if (exit == 0) {
		//NetCheckFinishedNotification
		[[NSNotificationCenter defaultCenter]
		 postNotificationName:NetCheckPassedNotification
		 object:self];
		return YES;
	}
	else {
		//NetCheckPassedNotification
		[[NSNotificationCenter defaultCenter]
		 postNotificationName:NetCheckFinishedNotification
		 object:self];
		return NO;
	}
	return NO;
}


-(BOOL)rebootScript
{
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSTask       *task;
	task = [[NSTask alloc] init];
	
	
	NSData *data;
	// Start
	NSPipe *pipe = [NSPipe pipe];

	NSString *script = @"/sbin/reboot";
	[task setLaunchPath:script];
	[task setArguments:[NSArray arrayWithObjects:nil]];
	[task setStandardOutput: pipe];
	//Set to help with Xcode debug log issues
	[task setStandardInput:[NSPipe pipe]];
	[task setStandardError: pipe];
	[task launch];
	
	//NSData *readData;
	NSFileHandle *file;
	file = [pipe fileHandleForReading];
	data = [file readDataToEndOfFile];
	[task waitUntilExit];

	
	// Post Finished Notifications
	int exit = [task terminationStatus];
	
	[ pool release];
	// BOOL Return value based on exit code
	if (exit == 0) {
		return YES;
	}
	else {
		return NO;
	}
	return NO;
}


-(NSString *)getUserPictureScript
{
	NSTask       *task;
	task = [[NSTask alloc] init];

	
	NSData *data;
	// Start
	NSPipe *pipe = [NSPipe pipe];
	// Grab both our system profile outputs
	NSString *getUserPicture = [mainBundle pathForResource:@"getUserDetails"
												  ofType:@"sh"];
	[task setLaunchPath:getUserPicture];
	[task setArguments:[NSArray arrayWithObjects:@"-u",
						 [unixIdField stringValue],
						 nil]];
	[task setStandardOutput: pipe];
	//Set to help with Xcode debug log issues
	[task setStandardInput:[NSPipe pipe]];
	[task setStandardError: pipe];
	[task launch];
	//NSData *readData;
	NSFileHandle *file;
	file = [pipe fileHandleForReading];
	data = [file readDataToEndOfFile];
	// We now have our full results in a NSString
	NSString *text = [[NSString alloc] initWithData:data 
										   encoding:NSASCIIStringEncoding];
	

	NSArray *components = [text componentsSeparatedByString:@"<result>"];
	NSString *returnValue ;
	if ([components count] > 0) {
		NSString *afterOpenBracket = [components objectAtIndex:1];
		components = [afterOpenBracket componentsSeparatedByString:@"</result>"];
		returnValue = [components objectAtIndex:0];
	}
	else {
		returnValue = UserPictureInvalidOutput;
	}


	
	if(debugEnabled)NSLog(@"Found Picture URL: (%@)",returnValue);

	
	return returnValue;
}

# pragma mark IKImageView

-(void)setUserPicture:(NSString *)userPictureLocation
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSURL *userPictureURL;
	// Create a URL out our string
	userPictureURL = [NSURL URLWithString:userPictureLocation];
	[userPictureView performSelectorOnMainThread:@selector(setImageWithURL:)
									  withObject:userPictureURL
								   waitUntilDone:false];
	[userPictureView setHidden:NO];
	[pool release];

}

- (IBAction)cancelOperation:(id)sender
{
	[self displayCancelWarning];
}

- (IBAction)updateUsersPassword:(id)sender
{
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	if (![self checkLocalBindScript]) {
		self.newUserName = [ unixIdField stringValue];
		self.newPassword = [ newPasswordField stringValue];
		self.oldPassword = [ newPasswordField stringValue];
		[self displayNetworkSyncPanel];
		return;
	}
	else {
		[ self makeWindowFullScreen];
	}


	// Below test is only relevent for the change feature which is disabled.
	if ([[ newPasswordField stringValue] isEqualToString:[newPasswordField stringValue]]) {
		if (![self checkBindScript]) {
			// Display and alert
			[self displayInvalidNewCredentials];
			// Reset the field to become the first responder
			[newPasswordField setStringValue:@""];
			[newPasswordField becomeFirstResponder];
			[self stopOldPasswordProgressIndicator];
			return;
		}
		plugins	= [[ Plugins alloc] init];
		
		// Set our script values
		

		plugins.userName = self.newUserName;
		plugins.oldUserName = self.oldUserName;
		plugins.oldPassword = self.oldPassword;
		// Manually setting for ESS right now
		plugins.newPassword = self.newPassword;
		
		[self expandMainProgressBox];
		[self startMainProgressIndicator];
		
		// This places the status Message panel onscreen
		[self performSelectorOnMainThread:@selector(displayStatusMessagePanel)
							   withObject:nil
							waitUntilDone:FALSE];
		
		[NSThread detachNewThreadSelector:@selector(runPluginScripts:)
								 toTarget:plugins
							   withObject:self];
		
		[mainButton setAction:@selector(cancelOperation:)];
		[mainButton setEnabled:NO];
	}
	else {
		// Display an alert telling the user of the mismatch
		[self displayPasswordMismatchAlert];
		// Set focus on the new password field
		[newPasswordField becomeFirstResponder];

	}

	[pool release];
}

-(void)runPlugins
{
	
}

# pragma mark NSBox


- (IBAction)expandOldPasswordBox:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self startUnixIdProgressIndicator];
	// Process the User Picture
	NSString *userPhotoURL = [ self getUserPictureScript];
	
	// Check if the users picture is in the Directory
	
	NSRange search = [userPhotoURL rangeOfString:UserPictureInvalidOutput
									  options:NSCaseInsensitiveSearch];
	if (search.location != NSNotFound) {
		if(debugEnabled)NSLog(@"Get User Details Script returned invalid user");
		[self displayInvalidNetworkID];
		[self stopUnixIdProgressIndicator];
	}
	else {
		// ZS: Moved here as retries were not working.
		// Grey out the field so users cannot change it.
		if(debugEnabled)NSLog(@"Valid User Details Returned");
		// Removing until validation is added
		//[unixIdField setEditable:NO];
		//[unixIdField setEnabled:NO];
		[self setUserPicture:userPhotoURL];
		[self stopUnixIdProgressIndicator];
		
		// Once done then
		NSRect frame = [window frame];
		// The extra +10 accounts for the space between the box and its neighboring views
		CGFloat sizeChange = [ oldPasswordBox frame].size.height;
		// Make the window bigger.
		frame.size.height += sizeChange;
		// Move the origin.
		frame.origin.y -= sizeChange;
		[window setFrame:frame display:YES animate:YES];
		// Show the extra box.
		[oldPasswordBox setHidden:NO];
		// Fix for bindings not working quickly enough.
		[mainButton setAction:@selector(updateUsersPassword:)];	
		[self showOldPasswordToggle:self];
		
	}
	[pool release];
}

- (IBAction)expandNewPasswordBox:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	// Grey out the old password field
	[newPasswordField setEditable:NO];
	[newPasswordField setEnabled:NO];
	[newPasswordClearField setEditable:NO];
	[newPasswordClearField setEnabled:NO];
	NSRect frame = [window frame];
	// The extra +10 accounts for the space between the box and its neighboring views
	CGFloat sizeChange = [ newPasswordBox frame].size.height;
	// Make the window bigger.
	frame.size.height += sizeChange;
	// Move the origin.
	frame.origin.y -= sizeChange;
	[window setFrame:frame display:YES animate:YES];
	// Show the extra box.
	[newPasswordBox setHidden:NO];
	[newPasswordField becomeFirstResponder];
	// Override the Return Key
	[mainButton setEnabled:NO];
	[newPasswordField setAction:@selector(focusOnVerifyField:)];
	[mainButton setAction:@selector(updateUsersPassword:)];	
	[pool release];
	
}


- (void)openNetMainBox
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[netMainBox setHidden:YES];
	NSRect frame = [networkCheckPanel frame];
	// The extra +10 accounts for the space between the box and its neighboring views
	CGFloat sizeChange = [ netMainBox frame].size.height;
	// Make the window bigger.
	frame.size.height += sizeChange;
	// Move the origin.
	frame.origin.y -= sizeChange;
	[networkCheckPanel setFrame:frame display:YES animate:YES];
	// Show the extra box.
	[netMainBox setHidden:NO];
	[self hideMainBoxContent:NO];
	[pool release];

	
}

- (void)openNetProgressBox
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[netProgressBox setHidden:YES];
	NSRect frame = [networkCheckPanel frame];
	// The extra +10 accounts for the space between the box and its neighboring views
	CGFloat sizeChange = [ netProgressBox frame].size.height;
	// Make the window bigger.
	frame.size.height += sizeChange;
	// Move the origin.
	frame.origin.y -= sizeChange;
	[networkCheckPanel setFrame:frame display:YES animate:YES];
	// Show the extra box.
	[netProgressBox setHidden:NO];
	[pool release];

	
}

- (void)expandMainProgressBox
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[newPasswordField setEditable:NO];
	[verifyNewPasswordField setEditable:NO];

	NSRect frame = [window frame];
	// The extra +10 accounts for the space between the box and its neighboring views
	CGFloat sizeChange = [ mainProgressBox frame].size.height;
	// Make the window bigger.
	frame.size.height += sizeChange;
	// Move the origin.
	frame.origin.y -= sizeChange;
	[window setFrame:frame display:YES animate:YES];
	// Show the extra box.
	[mainProgressBox setHidden:NO];
	[ mainButton setTitle:@"Cancel"];
	[ mainButton setHidden:YES];
	
	// Grab the number of scripts we have
	NSDictionary * scriptPlugins = [ settings objectForKey:@"scriptPlugins"];
	NSDictionary * mainRunLoopScripts = [ scriptPlugins objectForKey:@"mainRunLoopScripts"];
	
	// Enumerate our Script headers (Menu Headers)
	for(NSString *header in mainRunLoopScripts){
		NSDictionary *scriptHeader = [mainRunLoopScripts objectForKey:header];
		NSArray * itemScripts = [scriptHeader objectForKey:@"itemScripts"];
		// Set the number of scripts
		numberOfScripts = [ NSNumber numberWithInt:[itemScripts count]];
		// Set the level indicator
	}
	if(debugEnabled)NSLog(@"Found: %d scripts for this run loop",[numberOfScripts intValue]);

	[ scriptIndicator setMaxValue: [numberOfScripts doubleValue]];

	[pool release];
}

- (void)closeNetMainBox
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[netMainBox setHidden:YES];
	NSRect frame = [networkCheckPanel frame];
	CGFloat sizeChange = [netMainBox frame].size.height;
	
	// Make the window smaller.
	frame.size.height -= sizeChange;
	// Move the origin.
	frame.origin.y += sizeChange;
	[networkCheckPanel setFrame:frame display:YES animate:YES];
	// Hide the extra box.
	//--------------------------
	[pool release];
}

- (void)closeNetProgressBox
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[netProgressBox setHidden:YES];
	NSRect frame = [networkCheckPanel frame];
	CGFloat sizeChange = [netProgressBox frame].size.height;
	
	// Make the window smaller.
	frame.size.height -= sizeChange;
	// Move the origin.
	frame.origin.y += sizeChange;
	[networkCheckPanel setFrame:frame display:YES animate:YES];
	// Hide the extra box.
	//--------------------------
	[pool release];
}
# pragma mark -
# pragma mark Main Progress Bar
# pragma mark -


- (void)webView:(WebView *)sender decidePolicyForNavigationAction:
(NSDictionary *)actionInformation request:(NSURLRequest *)request
		  frame:(WebFrame *)frame decisionListener:(id
													<WebPolicyDecisionListener>)listener
{
	if ([[actionInformation objectForKey:WebActionNavigationTypeKey]
		 intValue] != WebNavigationTypeOther) {
		[listener ignore];
		[[NSWorkspace sharedWorkspace] openURL:[request URL]];
	}
	else
		[listener use];
}

- (void)closeAllBoxes
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	if (windowNeedsResize) {
		NSRect frame = [window frame];
		CGFloat sizeChange = [mainProgressBox frame].size.height;
		
		// Make the window smaller.
		frame.size.height -= sizeChange;
		// Move the origin.
		frame.origin.y += sizeChange;
		[window setFrame:frame display:YES animate:YES];
		// Hide the extra box.
		[mainProgressBox setHidden:YES];
		//--------------------------
		
		frame = [window frame];
		sizeChange = [newPasswordBox frame].size.height;
		
		// Make the window smaller.
		frame.size.height -= sizeChange;
		// Move the origin.
		frame.origin.y += sizeChange;
		[window setFrame:frame display:YES animate:YES];
		// Hide the extra box.
		[newPasswordBox setHidden:YES];
		//--------------------------
		
		frame = [window frame];
		sizeChange = [oldPasswordBox frame].size.height ;
		
		// Make the window smaller.
		frame.size.height -= sizeChange;
		// Move the origin.
		frame.origin.y += sizeChange;
		[window setFrame:frame display:NO animate:NO];
		// Hide the extra box.
		[oldPasswordBox setHidden:YES];
		
		
	}
	windowNeedsResize = NO;
	[pool release];
}

-(void)reboot
{
	NSDictionary* errorDict;
	 NSAppleEventDescriptor* returnDescriptor = NULL;
	 NSAppleScript* scriptObject = [[NSAppleScript alloc] initWithSource:
	 [NSString stringWithFormat:@"\
	 tell application \"Finder\" to restart\n"]];
	 returnDescriptor = [scriptObject executeAndReturnError: &errorDict];
	 [scriptObject release];
	[self rebootScript];
}

- (void)softReboot
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSDictionary* errorDict;
	NSAppleEventDescriptor* returnDescriptor = NULL;
	NSAppleScript* scriptObject = [[NSAppleScript alloc] initWithSource:
								   [NSString stringWithFormat:
									@"\
									tell app \"Finder\"\n\
									restart \n\
									end tell\n\
									"]];
	returnDescriptor = [scriptObject executeAndReturnError: &errorDict];
	[scriptObject release];
	[pool release];
}

- (void)quit
{
	NSLog(@"DEBUG: Was told to quit");
	// If we have been flagged then display the alert
	if (processComplete) {
		NSLog(@"DEBUG: Found process complete");
		[self performSelectorOnMainThread:@selector(displayProcessCompeletePanel)
							   withObject:nil
							waitUntilDone:TRUE];

	}
	else {
		if (requiredToRun) {
			// If we are required to run then we exit 1 , which relaunchs us
			// This is done via the LaunchD item  <key>SuccessfulExit</key> <false/> key
			NSLog(@"DEBUG: We are required to run, exiting 1 for respawn");
			exit(1);
		}
		else {
			NSLog(@"We not are required to run, exiting 0");
			[self closeProceedPanel];
			[self closeNetworkCheckPanel];
			[NSApp terminate:self];
		}

	}
}

# pragma mark -
# pragma mark NSNotification
# pragma mark -

- (void) reloadLevelIndicator:(NSNotification *) notification
{	
	NSDictionary *userinfo = [notification userInfo];
	NSNumber *currentScriptNumber = [userinfo objectForKey:@"currentScriptNumber"];
	if(debugEnabled) \
		NSLog(@"DEBUG: Receieved notification of script %d completion",[currentScriptNumber intValue]);

	[scriptIndicator setIntValue:[currentScriptNumber intValue]];
	// If we have reached the end of the line then
	if (numberOfScripts == currentScriptNumber ) {
		// ZS Disabled this as its not working right
		//windowNeedsResize = YES;
		//[self closeAllBoxes];
		[mainButton setEnabled:NO];
		[self stopMainProgressIndicator];
		// Set this var to let the util know to show the alert
		processComplete = YES;
		// Quit the app when done
		[self quit];

	}
}

-(void)networkCheckInProgress
{
	if ([netProgressBox isHidden]) {
		[self openNetProgressBox];
	}
	if (![netMainBox isHidden]) {
		[self closeNetMainBox];
	}

}

-(void)networkCheckFinished
{
	if ([netMainBox isHidden]) {
		[self openNetMainBox];
	}
	if (![netProgressBox isHidden]) {
		[self closeNetProgressBox];
	}
}

# pragma mark -
# pragma mark NSPanel & NSAlert
# pragma mark -

- (void)alertDidEnd:(NSAlert *)alert
		 returnCode:(NSInteger)returnCode
		contextInfo:(void *)contextInfo
{
    if (returnCode == NSAlertSecondButtonReturn) {
		// For the casper policy reporting
		NSLog(@"--------------------------------------------------------------------------------");
		NSLog(@"------------------------>User clicked Defer<-----------------------------------");
		NSLog(@"--------------------------------------------------------------------------------");

		[self quit];
    }
	[self runBatteryCheck];
}



# pragma mark NSPanels

-(void)displayNetworkPanel
{
	[ netProgressIndicator setUsesThreadedAnimation:YES];
	[NSApp beginSheet:networkCheckPanel
	   modalForWindow:window
		modalDelegate:self
	   didEndSelector:@selector(runBatteryCheck)
		  contextInfo:nil];
	
}

-(void)runBatteryCheck
{
	// Its not safe to call an NSAlert from background thread.
	[self performSelectorOnMainThread:@selector(displayBatteryAlert)
						   withObject:nil
						waitUntilDone:FALSE];
}

-(void)displayBatteryAlert
{
	if ([self checkBatteryPower]) {
		NSLog(@"Script Passed Battery Test");
	}
	else {
		NSLog(@"Script Failed Battery Test");
		// Activate Our Application
		[NSApp arrangeInFront:self];
		[NSApp activateIgnoringOtherApps:YES];
		// Display a standard alert
		NSAlert *alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:@"Ok"];
		[alert addButtonWithTitle:@"Cancel"];
		[alert setMessageText:@"Please plugin AC adapter"];
		[alert setInformativeText:@"This process may take around 15 mins and should be performed when your laptop is plugged into a wall outlet\
		 "];
		[alert setAlertStyle:NSWarningAlertStyle];
		//[alert runModal];
		[alert beginSheetModalForWindow:window
						  modalDelegate:self
						 didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
							contextInfo:nil];
		
		[alert release];
	}

}

-(void)displayChangePanel
{
	[NSApp beginSheet:changePanel
	   modalForWindow:window
		modalDelegate:self
	   didEndSelector:@selector(displayStatusMessagePanel)
		  contextInfo:nil];
}


-(void)displayNetworkSyncPanel
{
	// Set the old password to nothing so the field is empty
	[NSApp beginSheet:networkSyncPanel
	   modalForWindow:window
		modalDelegate:self
	   didEndSelector:@selector(updateUsersPassword:)
		  contextInfo:nil];
}

-(void)closeNetworkSyncPanel
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	if(debugEnabled)NSLog(@"Was told to close network panel");
	[networkSyncPanel orderOut:nil];
    [NSApp endSheet:networkSyncPanel];
	[pool release];
}

-(void)closeChangePanel
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	if(debugEnabled)NSLog(@"Was told to close revert panel");
	[changePanel orderOut:nil];
    [NSApp endSheet:changePanel];
	[pool release];
}

-(void)displayRevertPanel
{
	[self closeStatusMessagePanel];
	[NSApp beginSheet:revertPanel
	   modalForWindow:window
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];
}

-(void)displayStatusMessagePanel
{
	[self closeStatusMessagePanel];
	[NSApp beginSheet:statusMessagePanel
	   modalForWindow:window
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];
}

-(void)closeRevertPanel
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	if(debugEnabled)NSLog(@"Was told to close revert panel");
	[revertPanel orderOut:nil];
    [NSApp endSheet:revertPanel];
	[pool release];
}

-(void)bringToFront
{
	[NSApp requestUserAttention: NSInformationalRequest];
	[ window makeKeyAndOrderFront:nil];
	[ window setLevel:kCGMaximumWindowLevel];	
	[NSMenu setMenuBarVisible:NO];

}

-(void)makeWindowFullScreen
{
	
	NSLog(@"DEBUG: Making Window Fullscreen");
	fullScreenWindow	= [[FullScreenController alloc] initWithWindowNibName:@"FullScreenWindow"];
	[fullScreenWindow showWindow:[fullScreenWindow window]];

	[ [fullScreenWindow window] setOpaque:NO];
	if ([[fullScreenWindow window] respondsToSelector:@selector(setStyleMask:)]) {
		[ [fullScreenWindow window] setStyleMask:NSBorderlessWindowMask];
	}
	
	[ [fullScreenWindow window] setBackgroundColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.75]];
	[[fullScreenWindow window]
	 setFrame:[[fullScreenWindow window] frameRectForContentRect:[[[fullScreenWindow window] screen] frame]]
	 display:YES
	 animate:YES];
	[NSApp arrangeInFront:self];
	[NSApp activateIgnoringOtherApps:YES];
	[ window makeKeyAndOrderFront:self];
}

-(void)displayTotalFailurePanel
{
	[NSApp arrangeInFront:self];
	[NSApp activateIgnoringOtherApps:YES];
	[NSMenu setMenuBarVisible:NO];

	//[self makeWindowFullScreen];
	// "Activate" Application
	[NSApp beginSheet:totalFailurePanel
	   modalForWindow:window
		modalDelegate:self
	   didEndSelector:NULL
		  contextInfo:nil];
}
-(void)closeTotalFailurePanel
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	if(debugEnabled)NSLog(@"Was told to close totoal failure panel");
	[totalFailurePanel orderOut:nil];
    [NSApp endSheet:totalFailurePanel];
	[pool release];
}


-(void)displayProcessCompeletePanel
{
	// Get rid of our statusMessage panel
	[self closeStatusMessagePanel];
	// Show our process complete panel
	[NSApp beginSheet:processCompletePanel
	   modalForWindow:window
		modalDelegate:self
	   didEndSelector:NULL
		  contextInfo:nil];
	[NSApp requestUserAttention: NSInformationalRequest];

}

-(void)displayProceedPanel
{
	// Get rid of our statusMessage panel
	[self closeStatusMessagePanel];
	// Show our process complete panel
	[NSApp beginSheet:proceedPanel
	   modalForWindow:window
		modalDelegate:self
	   didEndSelector:@selector(proceedPanelDidEnd)
		  contextInfo:nil];
	[NSApp requestUserAttention: NSInformationalRequest];
	
	// Load the webview
	NSURL *url = [mainBundle URLForResource:@"proceedPanel"
							  withExtension:@"html"];
    NSURLRequest *requestObj = [NSURLRequest requestWithURL:url];
    [[webView mainFrame] loadRequest:requestObj];
	
}

-(void)closeProceedPanel
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	if(debugEnabled)NSLog(@"Was told to close proceed panel");
	[proceedPanel orderOut:nil];
    [NSApp endSheet:proceedPanel];
	[pool release];
}


-(void)closeNetworkCheckPanel
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	if(debugEnabled)NSLog(@"Was told to close network panel");
	[networkCheckPanel orderOut:nil];
    [NSApp endSheet:networkCheckPanel];
	[pool release];
}

-(void)closeProcessCompletePanel
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	if(debugEnabled)NSLog(@"Was told to close process complete panel");
	[processCompletePanel orderOut:nil];
    [NSApp endSheet:processCompletePanel];
	[pool release];
}


-(void)closeStatusMessagePanel
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	if (statusMessagePanel) {
		if(debugEnabled)NSLog(@"Was told to close status Message panel");
		[statusMessagePanel orderOut:nil];
		[NSApp endSheet:statusMessagePanel];
	}
	[pool release];
}

# pragma mark NSAlerts


-(void)displayPasswordMismatchAlert
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	// Activate Our Application
	[NSApp arrangeInFront:self];
	[NSApp activateIgnoringOtherApps:YES];
	// Display a standard alert
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"Cancel"];
	[alert setMessageText:@"Passwords do not match"];
	[alert setInformativeText:@"Please retype your NEW passwords again."];
	[alert setAlertStyle:NSWarningAlertStyle];
	[alert runModal];
	[alert release];
	[pool release];
}

-(void)displayInvalidNetworkID
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	// Activate Our Application
	[NSApp arrangeInFront:self];
	[NSApp activateIgnoringOtherApps:YES];
	// Display a standard alert
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"Ok"];
	[alert setMessageText:@"Username not found"];
	[alert setInformativeText:[NSString stringWithFormat:@"Please check the %@ username entered",[settings objectForKey:@"companyName"]]];
	[alert setAlertStyle:NSWarningAlertStyle];
	[alert runModal];
	[alert release];
	[pool release];
}


- (void)displayCancelWarning
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	// Activate Our Application
	[NSApp arrangeInFront:self];
	[NSApp activateIgnoringOtherApps:YES];
	// Display a standard alert
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"Ok"];
	[alert setMessageText:@"Reset In Progress"];
	[alert setInformativeText:@"The system is currently updating your password"];
	[alert setAlertStyle:NSWarningAlertStyle];
	[alert runModal];
	[alert release];
	[pool release];
}

- (void)displayInvalidNewCredentials
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	// Activate Our Application
	[NSApp arrangeInFront:self];
	[NSApp activateIgnoringOtherApps:YES];
	// Display a standard alert
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"Ok"];
	[alert setMessageText:@"Invalid Nike Password"];
	[alert setInformativeText:@"The password you entered is not correct"];
	[alert setAlertStyle:NSWarningAlertStyle];
	// Updated as our window level is so high we need everthing to be a panel
	[alert beginSheetModalForWindow:window
					  modalDelegate:self
					 didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
						contextInfo:nil];
	[alert release];
	
	[pool release];
}

- (void)openPageInSafari:(NSString *)url
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSDictionary* errorDict;
	NSAppleEventDescriptor* returnDescriptor = NULL;
	NSAppleScript* scriptObject = [[NSAppleScript alloc] initWithSource:
								   [NSString stringWithFormat:
									@"\
									tell app \"Safari\"\n\
									activate \n\
									make new document at end of documents\n\
									set URL of document 1 to \"%@\"\n\
									end tell\n\
									",url]];
	returnDescriptor = [scriptObject executeAndReturnError: &errorDict];
	[scriptObject release];
	[pool release];
	
}

# pragma mark -
# pragma mark IBAction Methods
# pragma mark -

- (IBAction)cancelButtonPressed:(id)sender
{
	[self closeRevertPanel];
	[self quit];
}



- (IBAction)showOldPasswordToggle:(id)sender
{
	if ([togglePasswordButton state] == NSOffState) {
		[newPasswordField setHidden:NO];
		[newPasswordField becomeFirstResponder];
		[newPasswordClearField setHidden:YES];
	}
	else {
		[newPasswordField setHidden:YES];
		[newPasswordClearField setHidden:NO];
		[newPasswordClearField becomeFirstResponder];
	}

}
- (IBAction)proceedOKButtonPressed:(id)sender
{
	[self closeProceedPanel];
}


- (IBAction)proceedCancelButtonPressed:(id)sender
{
	// For the casper policy reporting
	NSLog(@"--------------------------------------------------------------------------------");
	NSLog(@"------------------------>User clicked Postpone<-----------------------------------");
	NSLog(@"--------------------------------------------------------------------------------");
	
	[self quit];
}
- (IBAction)processCompleteOKButtonPressed:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	if(debugEnabled)NSLog(@"Process complete OK button pressed");
	[self closeProcessCompletePanel];
	[self closeRevertPanel];
	[self softReboot];
	[NSApp terminate:self];
	[pool release];
}

- (IBAction)opengVPNButtonPressed:(id)sender
{
	NSString *supportToolPath  = [settings objectForKey:@"vpnToolPath"];
	if(debugEnabled)NSLog(@"Using Support Tool path %@",supportToolPath);
	NSFileManager *myFileManager = [NSFileManager defaultManager];
	BOOL supportToolExists = [ myFileManager fileExistsAtPath:supportToolPath];
	
	if (supportToolExists){
		if(debugEnabled)NSLog(@"Found Support Tool path %@",supportToolPath);
		NSBundle *bundle = [NSBundle bundleWithPath:supportToolPath];
		NSString *path = [bundle executablePath];
		NSTask *task = [[NSTask alloc] init];
		[task setLaunchPath:path];
		[task launch];
		[task release];
		task = nil;	
	}
	else {
		NSLog(@"ERROR: Support Tool missing using bundle id %@",[settings objectForKey:@"vpnBundleID"]);
		NSWorkspace *ws = [NSWorkspace sharedWorkspace]; 
		NSString *appPath = [ws absolutePathForAppBundleWithIdentifier:[settings objectForKey:@"vpnBundleID"]]; 
		[ws launchApplication:appPath];
		if(debugEnabled)NSLog(@"Launched Support Tool");
	}
}

- (IBAction)usernameChangedACK:(id)sender
{
	[self closeChangePanel];
}

- (IBAction)shutdownNow:(id)sender
{
	[self closeTotalFailurePanel];
	[self quit];
	
}

-(IBAction)networkSyncPanelContinueButton:(id)sender
{
	[self closeNetworkSyncPanel];
}


- (IBAction)notNowButtonPressed:(id)sender
{
	[self closeNetworkCheckPanel];
	[self quit];
}

- (IBAction)tryAgainButtonPressed:(id)sender
{
	// Start our network Script
	[NSThread detachNewThreadSelector:@selector(netCheckScript)
							 toTarget:self
						   withObject:nil];
}


-(void)saveLastRunDate
{
	NSMutableDictionary *saveDict;
	NSFileManager * fileManager = [[NSFileManager alloc] init];
	if ([fileManager fileExistsAtPath:[settings objectForKey:@"saveFilePath"]]) {
		saveDict = [[ NSMutableDictionary alloc] initWithContentsOfFile:[settings objectForKey:@"saveFilePath"]];
	}
	else {
		saveDict = [[ NSMutableDictionary alloc] init];
	}
	
	[saveDict setObject:[NSDate date] forKey:@"LastRunDate"];
	[saveDict writeToFile:[settings objectForKey:@"saveFilePath"]atomically:NO];
	
}

- (NSString *)checkRunDay
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *filePath = [settings objectForKey:@"defFilePath"];
	
	int requiredDays = [[ settings objectForKey:@"requiredDays"]intValue] * 86400;

	
	if(debugEnabled)NSLog(@"Checking for file path: %@",filePath);
	// Check to see if the breadcrum file exists
	if ([fileManager fileExistsAtPath:filePath]){
		NSDate   *modDate      = [[fileManager attributesOfItemAtPath:filePath error:nil] fileModificationDate];
		NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];		
		[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
		[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
		NSLocale *enLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
		
		[dateFormatter setLocale:enLocale];
		// Realtive Date formatting on 10.6 and higher
		if ([dateFormatter respondsToSelector:@selector(setDoesRelativeDateFormatting:)]) {
			[dateFormatter setDoesRelativeDateFormatting:YES];
		}
		
		// Compare the Dates
		NSDate *todaysDate = [NSDate date];
		NSTimeInterval modDiff = [modDate timeIntervalSinceNow];
		NSTimeInterval todaysDiff = [todaysDate timeIntervalSinceNow];
		NSTimeInterval dateDiff = todaysDiff - modDiff;
		
		NSNumber *dateNumber = [NSNumber numberWithDouble:dateDiff];
		// Debug Messages
		if(debugEnabled) NSLog(@"The systems exact time was %@ seconds ago",[dateNumber stringValue] );
		if(debugEnabled) NSLog(@"The systems rounded time  was %d seconds ago",[dateNumber intValue] );
		
		// Check the date values
		int daysAgo = [dateNumber intValue] / 86400;
		
		NSString *dateString = [dateFormatter stringFromDate:modDate];
		if(debugEnabled)NSLog(@"Run Relative Date: %@", dateString);
		
		if (daysAgo >= (requiredDays / 86400) ) {
			self.requiredToRun = YES;
		}
		else {
			self.requiredToRun = NO;
		}
		int returnValue = [[ settings objectForKey:@"requiredDays"]intValue] - daysAgo;
		return [NSString stringWithFormat:@"%d",returnValue];

	}
	return [NSString stringWithFormat:@"%d",[[ settings objectForKey:@"requiredDays"]intValue]];
}



@end
