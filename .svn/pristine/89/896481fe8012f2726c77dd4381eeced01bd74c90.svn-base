//
//  DiagnosticModel.m
//  IPNetRouterX
//
//  Created by Peter Sichel on 12/7/06.
//  Copyright 2006 Sustainable Softworks. All rights reserved.
//

#import "DiagnosticModel.h"
//#import "ipkTypes.h"
#import PS_TNKE_INCLUDE
#import "PSSupport.h"

// Globals
NSString *DMNotification = @"DMNotification";

@implementation DiagnosticModel
+ (DiagnosticModel *)sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[DiagnosticModel alloc] init];
	}
	return sharedTask;
}

// ---------------------------------------------------------------------------------
//	¥ init
// ---------------------------------------------------------------------------------
- (id)init
{
    if (self = [super init]) {
        // initialize our instance variables
		int i;
		for (i=0; i<kMemStat_last; i++) {
			bzero(&memStatArray[i], sizeof(KFT_memStat_t));
		}
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	¥ dealloc
// ---------------------------------------------------------------------------------
- (void)dealloc {
	[super dealloc];
}

#pragma mark -- Logistics --

// ---------------------------------------------------------------------------------
//	¥ addObserver
// ---------------------------------------------------------------------------------
- (void)addObserver:(id)target withSelector:(SEL)method {
    [[NSNotificationCenter defaultCenter] addObserver:target 
    selector:method 
    name:DMNotification 
    object:self];
}

// ---------------------------------------------------------------------------------
//	¥ removeObserver
// ---------------------------------------------------------------------------------
- (void)removeObserver:(id)target {
    [[NSNotificationCenter defaultCenter] removeObserver:target
        name:DMNotification
        object:self];
}

// ---------------------------------------------------------------------------------
//	¥ updateParameter
// ---------------------------------------------------------------------------------
// Notify listeners when state changes
- (BOOL)updateParameter:(NSString *)name withObject:(id)anObject
{
    NSDictionary* myDictionary;
	if (name && anObject) {
		myDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:anObject, name, nil];
		// notify listeners with dictionary
		[[NSNotificationCenter defaultCenter]
			postNotificationName:DMNotification
			object:self
			userInfo:myDictionary];		
		[myDictionary release];
	}
	return YES;
}


#pragma mark -- receive data --
// ---------------------------------------------------------------------------------
//	¥ receiveMemStatUpdate:
// ---------------------------------------------------------------------------------
- (void)receiveMemStatUpdate:(NSData *)messageData
{
	ipk_memStatUpdate_t* updateMessage;
	KFT_memStat_t* entry;
	int j, length, howMany;
	int type;
	// update for current message
	updateMessage = (ipk_memStatUpdate_t *)[messageData bytes];
	length = updateMessage->length;
	howMany = (length-8)/sizeof(KFT_memStat_t);
	for (j=0; j<howMany; j++) {
		// memStat entry
		entry = &updateMessage->memStatUpdate[j];
		// stat type
		type = entry->type;
		// copy to corresponding row in array
		memcpy(&memStatArray[type-1], entry, sizeof(KFT_memStat_t));
	}
	// notify any listeners we have new data
	[self updateParameter:@"memStatUpdate" withObject:@"memStatUpdate"];
}

#pragma mark -- NSTable data source --
// ---------------------------------------------------------------------------------
//	¥ numberOfRowsInTableView
// ---------------------------------------------------------------------------------
- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return kMemStat_last-1;
}
// ---------------------------------------------------------------------------------
//	¥ tableView:objectValueForTableColumn:row:
// ---------------------------------------------------------------------------------
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	NSString* returnValue = nil;
	KFT_memStat_t* entry;
	NSString* cid = [tableColumn identifier];
	if (row < kMemStat_last) {
		entry = &memStatArray[row];
		if ([cid isEqualTo:kColType]) {
			switch (entry->type) {
				case kMemStat_avlTree:
					returnValue = @"AVL tree";
					break;
				case kMemStat_avlNode:
					returnValue = @"AVL node";
					break;
				case kMemStat_trigger:
					returnValue = @"Trigger";
					break;
				case kMemStat_connection:
					returnValue = @"Connection";
					break;
				case kMemStat_nat:
					returnValue = @"NAT";
					break;
				case kMemStat_portMap:
					returnValue = @"Port Map";
					break;
				case kMemStat_callback:
					returnValue = @"Callback";
					break;
				case kMemStat_fragment:
					returnValue = @"Fragment";
					break;
			}
		}
		else if ([cid isEqualTo:kColFreeCount]) {
			returnValue = [NSString stringWithFormat:@"%d",entry->freeCount];
		}
		else if ([cid isEqualTo:kColTableCount]) {
			returnValue = [NSString stringWithFormat:@"%d",entry->tableCount];
		}
		else if ([cid isEqualTo:kColAllocated]) {
			returnValue = [NSString stringWithFormat:@"%d",entry->allocated];
		}
		else if ([cid isEqualTo:kColReleased]) {
			returnValue = [NSString stringWithFormat:@"%d",entry->released];
		}
		else if ([cid isEqualTo:kColAllocFailed]) {
			returnValue = [NSString stringWithFormat:@"%d",entry->allocFailed];
		}
		else if ([cid isEqualTo:kColLeaked]) {
			returnValue = [NSString stringWithFormat:@"%d",entry->leaked];
		}
	}
	return returnValue;
}

@end
