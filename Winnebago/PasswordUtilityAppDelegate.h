//
//  PasswordUtilityAppDelegate.h
//
//  Created by Zack Smith on 11/16/11.
//  Copyright 2011 318 All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import <ApplicationServices/ApplicationServices.h>
#import <WebKit/WebKit.h>

@class IKImageView;

@class Plugins;
@class GlobalStatus;
@class FullScreenController;
@class FullscreenWindow;

@interface PasswordUtilityAppDelegate : NSObject {
    IBOutlet NSWindow *window;
	// Out Image Kit
	IBOutlet IKImageView *userPictureView;

	// Our Text Fields
	IBOutlet NSTextField *unixIdField;
	IBOutlet NSSecureTextField *newPasswordField;
	IBOutlet NSTextField *newPasswordClearField;
	
	IBOutlet NSButton *togglePasswordButton;

	//IBOutlet NSSecureTextField *newPasswordField;
	IBOutlet NSSecureTextField *verifyNewPasswordField;
	// Our Progress Indicator
	IBOutlet NSProgressIndicator *unixIdProgressIndicator;
	IBOutlet NSProgressIndicator *oldPasswordProgressIndicator;
	IBOutlet NSProgressIndicator *newPasswordProgressIndicator;
	IBOutlet NSProgressIndicator *mainProgressIndicator;
	IBOutlet NSProgressIndicator *netProgressIndicator;

	// Out Buttons
	IBOutlet NSButton *mainButton;
	// NSImageView - Our User Picture
	IBOutlet NSImageView *mainPicture;
	// NSBox
	IBOutlet NSBox *oldPasswordBox;
	IBOutlet NSBox *newPasswordBox;
	IBOutlet NSBox *mainProgressBox;
	
	// Our NSPanel Boxes
	IBOutlet NSBox *netProgressBox;
	IBOutlet NSBox *netMainBox;
	// NSPanels
	IBOutlet NSPanel *networkCheckPanel;
	IBOutlet NSPanel *processCompletePanel;
	IBOutlet NSPanel *statusMessagePanel;
	IBOutlet NSPanel *changePanel;
	IBOutlet NSPanel *revertPanel;
	IBOutlet NSPanel *totalFailurePanel;
	IBOutlet NSPanel *proceedPanel;
	IBOutlet NSPanel *networkSyncPanel;

	// Our Network Check Panel
	IBOutlet NSImageView *alertIcon;
	IBOutlet NSTextField *alertTextField;

	IBOutlet NSButton *openVPNButton;
	IBOutlet NSButton *notNowButton;
	IBOutlet NSButton *tryAgainButton;
	
	IBOutlet NSLevelIndicator *scriptIndicator;
	
	IBOutlet WebView *webView;
	
	// Text Properties
	NSString *processCompleteText;
	NSString *networkCheckText;
	NSString *revertText;
	NSString *failureText;
	
	NSString *oldPassword;
	NSString *newPassword;
	
	BOOL windowNeedsResize;
	BOOL debugEnabled;
	BOOL processComplete;
	BOOL usernameChange;
	
	BOOL netCheckRunning;
	BOOL requiredToRun;
	// Our Custom classes
	Plugins *plugins;
	
	// Handle our nstasks
	NSFileHandle *fileHandle;
	
	// Reference to this bundle
	NSBundle *mainBundle;
	NSUserDefaults *settings;
	NSNumber *numberOfScripts;
	
	NSString *newUserName;
	NSString *oldUserName;
	GlobalStatus  *globalStatusController;
	FullScreenController *fullScreenWindow;
	
	NSString *daysRemaining;

}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet WebView *webView;

@property (retain) NSString* oldPassword;
@property (retain) NSString* newUserName;
@property (retain) NSString* newPassword;
@property (retain) NSString* oldUserName;
@property (retain) NSString*  daysRemaining;

// Text Properties
@property (retain) NSString* processCompleteText;
@property (retain) NSString* networkCheckText;
@property (retain) NSString* revertText;
@property (retain) NSString* failureText;

@property (assign) BOOL netCheckRunning;
@property (assign) BOOL requiredToRun;

- (void)readInSettings;
- (void)closeAllBoxes;
// Display NSAlert Methods -- should consolidate
- (void)displayPasswordMismatchAlert;
- (void)displayInvalidNetworkID;
- (void)displayCancelWarning;
- (void)displayInvalidNewCredentials;
// User Picture Stuff
- (void)setUserPicture:(NSString *)userPictureLocation;
- (void)stopMainProgressIndicator;
- (void)stopMainProgressIndicator;
- (void)stopNetProgressIndicator;
- (void)startNetProgressIndicator;
- (void)startUnixIdProgressIndicator;
- (void)stopUnixIdProgressIndicator;
- (void)startNewPasswordProgressIndicator;
- (void)stopNewPasswordProgressIndicator;

- (void)expandMainProgressBox;
- (void)displayNetworkPanel;
- (void)displayChangePanel;
- (void)displayNetworkSyncPanel;
- (void)displayRevertPanel;
- (void)displayTotalFailurePanel;
- (void)closeNetworkSyncPanel;

- (NSString *)getUserPictureScript;
- (NSString *)checkUserScript;

// Our Various Button Actions
- (IBAction)expandOldPasswordBox:(id)sender;
- (IBAction)expandNewPasswordBox:(id)sender;
- (IBAction)updateUsersPassword:(id)sender;
- (IBAction)focusOnVerifyField:(id)sender;
- (IBAction)cancelOperation:(id)sender;
- (IBAction)networkSyncPanelContinueButton:(id)sender;


- (void)openPageInSafari:(NSString *)url;
// Out NSButton Methods


- (IBAction)opengVPNButtonPressed:(id)sender;
- (IBAction)notNowButtonPressed:(id)sender;
- (IBAction)tryAgainButtonPressed:(id)sender;
- (IBAction)processCompleteOKButtonPressed:(id)sender;
- (IBAction)proceedOKButtonPressed:(id)sender;
- (IBAction)proceedCancelButtonPressed:(id)sender;

- (IBAction)showOldPasswordToggle:(id)sender;
- (IBAction)cancelButtonPressed:(id)sender;
- (BOOL)rebootScript;
- (IBAction)usernameChangedACK:(id)sender;
- (IBAction)shutdownNow:(id)sender;


// NSPanel Methods
- (void)closeNetworkCheckPanel;
- (void)closeProcessCompletePanel;
- (void)closeStatusMessagePanel;
- (void)closeProceedPanel;
- (BOOL)netCheckScript;
- (void)proceedPanelDidEnd;

-(BOOL)checkBatteryPower;
-(void)displayBatteryAlert;

- (void)openNetProgressBox;
- (void)openNetMainBox;
- (void)closeNetProgressBox;
- (void)closeNetMainBox;
- (void)quit;
- (void)reboot;
- (void)startOldPasswordProgressIndicator;
- (void)stopOldPasswordProgressIndicator;

- (void)networkCheckInProgress;
- (void)networkCheckFinished;
- (void)hideMainBoxContent:(BOOL)hide;
- (BOOL)checkBindScript;
- (void)displayProcessCompeletePanel;
- (void)displayStatusMessagePanel;
- (void)displayProceedPanel;
- (void)reloadLevelIndicator:(NSNotification *) notification;
- (void)criticalFailure:(NSNotification *)aNotification;
- (void)recoveredFailure:(NSNotification *)aNotification;
- (void)totalFailure:(NSNotification *)aNotification;
- (void)revertChangesScript;
- (void)makeWindowFullScreen;
- (void)softReboot;
- (void)bringToFront;
- (void)alertDidEnd:(NSAlert *)alert
		 returnCode:(NSInteger)returnCode
		contextInfo:(void *)contextInfo;

-(void)runBatteryCheck;

-(void)saveLastRunDate;

- (NSString *)checkRunDay;
@end
