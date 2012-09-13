//
//  SummaryWindowController.h
//
//  Created by Zack Smith on 8/17/11.
//  Copyright 2011 318. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Constants.h"


@interface SummaryWindowController : NSObject {
	//IBOutlet
	IBOutlet NSWindow *window;
	IBOutlet NSTableView *tableView;
	
	// NSButtons
	IBOutlet NSPopUpButton *toggleSummaryPredicateButton;
	IBOutlet NSButton *processCompleteButton;


	//NSTableColumns
	IBOutlet NSTableColumn *statusCol;
	IBOutlet NSTableColumn *discriptionCol;
	IBOutlet NSTableColumn *statusTxtCol;
	
	//NSArrays
	NSMutableArray *globalStatusArray;
	
	// Standard ivar Set
	NSBundle *mainBundle;
	NSDictionary *settings;
	
	NSMutableArray *aBuffer;

	NSString *statusPredicate;
	
	NSDictionary *lastGlobalStatusUpdate;

	BOOL debugEnabled;

}
// IBActions
-(IBAction)toggleSummaryPredicate:(id)sender;

// void
- (void)readInSettings ;
// NSTableView
- (void)reloadTableBuffer:(NSDictionary *)globalStatusUpdate;
- (void)reloadTableBufferNow:(NSNotification *) notification;

// NSMutableArray
- (NSMutableArray*)aBuffer;


@end
