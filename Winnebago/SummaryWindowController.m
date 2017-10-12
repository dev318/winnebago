//
//  SummaryWindowController.m
//
//  Created by Zack Smith on 8/17/11.
//  Copyright 2011 318. All rights reserved.
//

#import "SummaryWindowController.h"
#import "StatusIconCell.h"
#import "Constants.h"


@implementation SummaryWindowController

- (id)init
{	
	[super init];
	[self readInSettings];
	if(debugEnabled)NSLog(@"DEBUG: init OK in SummaryWindowController");
	if(debugEnabled)NSLog(@"DEBUG: Registering for ReceiveStatusUpdateNotification");
	//ReceiveStatusUpdateNotification
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadTableBufferNow:) 
                                                 name:ReceiveStatusUpdateNotification
                                               object:nil];
	return self;
}

- (void)awakeFromNib {
	// StatusUpdateNotification
	// Register for notifications on Global Status Array updates
	// Ask for an update to the global status array on init
	if(debugEnabled)NSLog(@"Summary Window Requesting Status Update from controller");
	[[NSNotificationCenter defaultCenter]
	 postNotificationName:RequestStatusUpdateNotification
	 object:self];

	// Hide the Dock
	StatusIconCell *statusIconCell = [[StatusIconCell alloc] init];
	
	[discriptionCol setDataCell:statusIconCell];
	// Set the menu to blank
	[toggleSummaryPredicateButton setTitle:@""];
	[tableView reloadData];

}

-(void)dealloc 
{ 
	// Remove observer for window close
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	// Release Array buffer
	[aBuffer release];
	//[self.globalStatusArray release];
	[super dealloc]; 
}

# pragma mark -
# pragma mark Notification Observered Methods
# pragma mark -
// Need to update for panel close
- (void)windowClosing:(NSNotification*)aNotification {
	if(debugEnabled)NSLog(@"Received window close notification");
	if (aBuffer) {
		if(debugEnabled)NSLog(@"Clearing the current table buffer");
		[aBuffer removeAllObjects];
	}
}


# pragma mark -
# pragma mark NSTableView Methods
# pragma mark -

- (NSMutableArray*)aBuffer
{
	return aBuffer;
}


- (id)tableView:(NSTableView *)tableView 
objectValueForTableColumn:(NSTableColumn *)tableColumn 
			row:(NSInteger)row
{
	if (![aBuffer count]) {
		statusPredicate = TaskPassed;
		//Disable the Attempt to Repair Button
		return nil;
	}
	else {
		statusPredicate = nil;
	}
	if (row > [aBuffer count] -1) {
		if(debugEnabled)NSLog(@"DEBUG:We Have run out of rows?");
		return nil;
	}
	if(debugEnabled)NSLog(@"DEBUG:Processing row: %ld of %lu",(long)row,[aBuffer count] -1);
	NSImage *lrg_green = [[NSImage alloc] initWithContentsOfFile: [ mainBundle
																   pathForResource:@"lrg_green" ofType:@"png"]];
	NSImage *lrg_yellow = [[NSImage alloc] initWithContentsOfFile: [ mainBundle
																	pathForResource:@"lrg_yellow" ofType:@"png"]];
	NSImage *lrg_red = [[NSImage alloc] initWithContentsOfFile: [ mainBundle
																 pathForResource:@"lrg_red" ofType:@"png"]];
	if (statusCol == tableColumn) {
		NSString *status = [[aBuffer objectAtIndex:row] objectForKey:@"status"];
		if ([status isEqualToString:TaskPassed]) {
			if (row != -1) return lrg_green;
		}
		if ([status isEqualToString:TaskWarning]) {
			if (row != -1) return lrg_yellow;
		}
		if ([status isEqualToString:TaskCritical]) {
			if (row != -1) return lrg_red;
		}
	}
	if (discriptionCol == tableColumn) {
		NSMutableDictionary *displayDictionary = [[NSMutableDictionary alloc] init];
		if ([aBuffer objectAtIndex:row]) {
			return [aBuffer objectAtIndex:row];

		}
		else {
			NSString *nameValue = @"Generic Test";
			[displayDictionary setValue:nameValue forKey:@"title"];
			NSString *image = @"generic_sm";
			[displayDictionary setValue:image forKey:@"image"];
			return displayDictionary;
		}
		
	}
	if (statusTxtCol == tableColumn) {
		if ([aBuffer objectAtIndex:row] !=nil) {
			NSString * discription = @"";
			NSString * status = @"";
			NSString * metric = @"";
			NSString * nsStr = @"";
			// Passed Text
			NSString *passedText = @"";
			NSString *warningText = @"";
			NSString *criticalText = @"";
			
			if ([[aBuffer objectAtIndex:row] objectForKey:@"discription"] !=nil) {
				discription =  [[aBuffer objectAtIndex:row] objectForKey:@"discription"];
				if(debugEnabled)NSLog(@"Processed Description: %@",discription);
				
			}
			if ([[aBuffer objectAtIndex:row] objectForKey:@"status"] !=nil) {
				status =  [[aBuffer objectAtIndex:row] objectForKey:@"status"];
				if(debugEnabled)NSLog(@"Processed Status: %@",status);
				
			}
			if ([[aBuffer objectAtIndex:row] objectForKey:@"metric"] !=nil) {
				metric =  [[aBuffer objectAtIndex:row] objectForKey:@"metric"];
				if(debugEnabled)NSLog(@"Metric Status: %@",metric);
				
			}
			
			if ([status isEqualToString:TaskPassed]) {
				passedText = [[ settings objectForKey:discription] objectForKey:@"passedText"];
				if(metric && passedText){
					nsStr =[NSString stringWithFormat: passedText, metric];
				}
				else {
					nsStr = passedText;
				}
				[ toggleSummaryPredicateButton addItemWithTitle:TaskPassed];
				if (statusPredicate) {
					[toggleSummaryPredicateButton setTitle:statusPredicate];
				}
			}
			if(debugEnabled)NSLog(@"Found Passed Text: %@",passedText);
			if ([status isEqualToString:TaskWarning]) {
				warningText = [[ settings objectForKey:discription] objectForKey:@"warningText"];
				if(metric && warningText){
					nsStr =[NSString stringWithFormat: warningText, metric];
				}
				else{
					nsStr = warningText;
				}
				[ toggleSummaryPredicateButton setEnabled:YES];
				[ toggleSummaryPredicateButton addItemWithTitle:TaskWarning];
				if (statusPredicate) {
					[toggleSummaryPredicateButton setTitle:statusPredicate];
				}
			}
			if ([status isEqualToString:TaskCritical]) {
				criticalText = [[ settings objectForKey:discription] objectForKey:@"criticalText"];
				if(metric && criticalText){
					nsStr =[NSString stringWithFormat: criticalText, metric];
				}
				else {
					nsStr = criticalText;
				}
				[ toggleSummaryPredicateButton setEnabled:YES];
				[ toggleSummaryPredicateButton addItemWithTitle:TaskCritical];
				if (statusPredicate) {
					[toggleSummaryPredicateButton setTitle:statusPredicate];
				}
				
			}
			
			NSMutableParagraphStyle *paragraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
			
			[paragraphStyle setLineBreakMode:NSLineBreakByWordWrapping];
			
			
			NSMutableAttributedString * attributedStr = [[[NSMutableAttributedString alloc] initWithString:nsStr] autorelease];
			[attributedStr
			 addAttribute:NSParagraphStyleAttributeName
			 value:paragraphStyle
			 range:NSMakeRange(0,[attributedStr length])];
			
			if(debugEnabled)NSLog(@"Generated Attribute String:%@",attributedStr);
			if (row != -1) return attributedStr;
		}
		
	}
	else {
		return nil;
		
	}
	return nil;
}


// Table View Protocol
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	if ([aBuffer count] != 0) {
		return ([aBuffer count]);
		
	}
	else {
		return ([aBuffer count] -1);
	}
}

- (void) reloadTableBufferNow:(NSNotification *) notification
{	
	if(debugEnabled)NSLog(@"DEBUG:Summary Window received ReceiveStatusUpdateNotification notification");
	lastGlobalStatusUpdate = [notification userInfo];
	[self reloadTableBuffer:lastGlobalStatusUpdate];
}

-(void)reloadTableBuffer:(NSDictionary *)globalStatusUpdate
{
	if(debugEnabled)NSLog(@"DEBUG: Was Told to Reload Table Buffer...");
	if (aBuffer) {
		if(debugEnabled)NSLog(@"DEBUG: found existing buffer releasing");
		[aBuffer release];
	}
	
	globalStatusArray = [[NSMutableArray alloc] initWithArray:[globalStatusUpdate objectForKey:@"globalStatusArray"]];
	if(debugEnabled)NSLog(@"DEBUG: Notification Array: %@",globalStatusArray);
	NSMutableDictionary *saveDict = [[ NSMutableDictionary alloc] init];
	
	for (id element in globalStatusArray) {
		[saveDict setObject:[element objectForKey:@"status"] forKey:[element objectForKey:@"title"]];
		NSString * outputTitle = [ NSString stringWithFormat:@"%@ Output",[element objectForKey:@"title"]];
		[saveDict setObject:[element objectForKey:@"output"] forKey:outputTitle];

    }
	[saveDict setObject:[NSDate date] forKey:@"LastRunDate"];
	[saveDict writeToFile:[settings objectForKey:@"saveFilePath"]atomically:NO];
	
	/*
	if(debugEnabled)NSLog(@"DEBUG: reloadTableBuffer with globalStatusArray: %@",globalStatusArray );
	NSPredicate *summaryPredicate;
	// If the pop-up menu has not been activated then 
	// filter the Passed Results only showing warning and critical messages

	if (!statusPredicate) {
		summaryPredicate = [NSPredicate predicateWithFormat:@"status != %@",TaskPassed];
		[toggleSummaryPredicateButton setTitle:@""];
		
	}
	else {
		summaryPredicate = [NSPredicate predicateWithFormat:@"status = %@",statusPredicate];
	}
	NSArray *matchingObjects;
	if ([[globalStatusArray filteredArrayUsingPredicate:summaryPredicate] count] >0) {
		matchingObjects = [[NSArray alloc] initWithArray:[globalStatusArray filteredArrayUsingPredicate:summaryPredicate]];
	}
	else {
		matchingObjects = [[NSArray alloc] init];
	}
	
	
	if(debugEnabled)NSLog(@"DEBUG: Predicate Matching Objects:%@",matchingObjects);
	
	
	if ([matchingObjects count] > 0) {
		aBuffer = [[NSMutableArray alloc] initWithArray:matchingObjects];
	}
	else {
		if(debugEnabled)NSLog(@"DEBUG: No matching objects found with predicate");
		aBuffer = [[NSMutableArray alloc] init];
	}*/
	aBuffer = [[ NSMutableArray alloc] initWithArray:globalStatusArray];
	// Reload the table
	if (statusPredicate) {
		[toggleSummaryPredicateButton setTitle:statusPredicate];
		// Reset for the next go around
		[statusPredicate release];
	}
	if(debugEnabled)NSLog(@"DEBUG: aBuffer: %@",aBuffer);
	if(debugEnabled)NSLog(@"DEBUG: Telling table to reload data");

	[tableView performSelectorOnMainThread:@selector(reloadData)
								withObject:nil
							 waitUntilDone:false];
}
# pragma mark -
# pragma mark Class Methods
# pragma mark -

- (void)readInSettings 
{ 	
	mainBundle = [NSBundle bundleForClass:[self class]];
	NSString *settingsPath = [mainBundle pathForResource:SettingsFileResourceID
												  ofType:@"plist"];
	settings = [[NSDictionary alloc] initWithContentsOfFile:settingsPath];
}

# pragma mark -
# pragma mark IBAction Methods
# pragma mark -

-(IBAction)toggleSummaryPredicate:(id)sender
{	
	statusPredicate = [ toggleSummaryPredicateButton title];
	if(debugEnabled)NSLog(@"DEBUG: updating status predicate to :%@",statusPredicate);
	[[NSNotificationCenter defaultCenter]
	 postNotificationName:RequestStatusUpdateNotification
	 object:self];
}


@end
