//
//  NATViewWindowC.m
//  IPNetRouterX
//
//  Created by Peter Sichel on Mon Jan 3 2004.
//  Copyright (c) 2004 Sustainable Softworks, Inc. All rights reserved.
//

#include "Test_In_Client.h"
#import "NATViewWindowC.h"
#import "NatTable.h"
#import "NatEntry.h"
#import "PSSharedDictionary.h"
#import "SentryModel.h"
#import "SentryState.h"
#import "PSSupport.h"
// NKE
#import PS_TNKE_INCLUDE
#import "SentryController.h"
#import "kft.h"
#import "kftNatTable.h"

@implementation NATViewWindowC
- init
{
    if (self = [super init]) {
        // initialize instance vars
		// use awakeFromNib
    }
    return self;
}
- (void)dealloc
{
	// release any vars we allocated
	// use windowWillClose
    [super dealloc];
}

- (void)awakeFromNib {
	PSSharedDictionary* sd = [PSSharedDictionary sharedInstance];

	// Retain ourself so caller can release reference.  Released in windowWillClose:
	[self retain];	
	// disable if application is not yet registered
    if ([[sd objectForKey:kCheck1] intValue] &&
		[[sd objectForKey:kCheck2] intValue] &&
		[[sd objectForKey:kCheck3] intValue]) {
		[natMonitor setEnabled:YES];
	}
	else {
		[natMonitor setEnabled:NO];
		[statusInfo setStringValue:NSLocalizedString(@"Trial period expired",
			@"Trial period expired")];
	}
	// set data source for display table
	[tableView setDataSource:[[[SentryModel sharedInstance] sentryState] natTable]];
	// setup to receive messages from SentryState
	[[[SentryModel sharedInstance] sentryState] addObserver:self withSelector:@selector(receiveNotification:)];
    // restore settings
    // set double click action
//    [tableView setTarget:self];
//    [tableView setDoubleAction:@selector(doubleAction:)];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
    NSWindow* theWindow;
    
    // remember window frame
    theWindow = [aNotification object];
    [theWindow saveFrameUsingName:kNATViewName];
    // remember settings
    // release ourself
    [self autorelease];
}

// ---------------------------------------------------------------------------
//	¥ receiveNotification
// ---------------------------------------------------------------------------
// Receive notification from SentryState when model state changes
// Update parameters passed in dictionary
// Uses key as the name of a class or instance and sets its value
- (void)receiveNotification:(NSNotification *)aNotification
{
    NSDictionary* dictionary;
	NSEnumerator* en;
    id key;
    id object;
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	do {    

		dictionary = [aNotification userInfo];
		en = [dictionary keyEnumerator];

		while ((key = [en nextObject])) { 
			/* code that uses the returned key */
			//if (![key isKindOfClass:[NSString class]]) continue; 
			// update tableView
			if ([key isEqualTo:SS_natTable]) {
				[tableView reloadData];
				continue;
			}
			object = [dictionary objectForKey:key];

			// status
			if ([key isEqualTo:@"statusInfo"])	{
				[statusInfo setStringValue:object];
				continue;
			}
			if ([key isEqualTo:@"statusInfoAppend"]) {
				NSRange range;
				// ignore ppp0 errors here
				range = [object rangeOfString:@"ppp0"];
				if (!range.length) {
					NSString* str;
					str = [[statusInfo stringValue] stringByAppendingString:object];
					[statusInfo setStringValue:str];
				}
				continue;
			}
		}	// while ((key = [enumerator nextObject]))
	} while (false);
    [pool release];
}


// ---------------------------------------------------------------------------
//	¥ natDelete
// ---------------------------------------------------------------------------
- (IBAction)natDelete:(id)sender
{
	NatTable* natT;
	NatEntry* natE;
	NSEnumerator* en;
	NSNumber* num;
	NSMutableArray* array;
	// send to NKE
	unsigned char buffer[kUpdateBufferSize];
	ipk_natUpdate_t* message;
	int sizeLimit;
	int j;
	int deleteCount = 0;
	int remainCount;

	// setup nat update message
	message = (ipk_natUpdate_t*)&buffer[0];
	message->length = 8;	// ofset to first entry
	message->type = kNatUpdate;
	message->version = 0;
	message->flags = 0;
	// calculate size limit that still leaves room for another entry
	sizeLimit = kUpdateBufferSize - sizeof(KFT_natEntry_t);
	j = 0;
	
	natT = [tableView dataSource];
	array = [NSMutableArray arrayWithCapacity:[natT count]];
	// gather entries to be deleted before altering indexes
	en = [tableView selectedRowEnumerator];
	while (num = [en nextObject]) [array addObject:[natT objectAtIndex:[num intValue]]];
	// now remove list of entries
	en = [array objectEnumerator];
	while (natE = [en nextObject]) {
		// add to update message
		if (natObjectToData(natE, &message->natUpdate[j]) == 0) {
			deleteCount += 1;
			message->natUpdate[j].flags = kNatFlagDelete;
			message->length += sizeof(KFT_natEntry_t);
			j += 1;
			// if message buffer is full, send it
			if (message->length >= sizeLimit) {
				// TEST_IN_CLIENT
				KFT_receiveMessage((ipk_message_t*)message);
				// NKE
				[[SentryController sharedInstance] sendURL:kKFTReceiveMessage withObject:
					[NSData dataWithBytes:(void *)message length:message->length]];
				message->length = 8;	// ofset to first entry
				message->flags = 0;
				j = 0;
			}
		}
	}
	// are there any updates to send?
	if (j > 0) {
		// send message to each active controller
		// TEST_IN_CLIENT
		KFT_receiveMessage((ipk_message_t*)message);
		// NKE
		[[SentryController sharedInstance] sendURL:kKFTReceiveMessage withObject:
			[NSData dataWithBytes:(void *)message length:message->length]];
	}
	#if TEST_IN_CLIENT
		remainCount = KFT_natCount();
	#else
		remainCount = [[SentryController sharedInstance] sendURL:kKFTNatCount];
	#endif
	
	[statusInfo setStringValue:[NSString stringWithFormat:@"%d deleted, %d remain",deleteCount, remainCount]];
	// refresh tableView
	[tableView deselectAll:self];
	[tableView reloadData];
}

- (IBAction)natRefresh:(id)sender
{
	[statusInfo setStringValue:@""];
	[[SentryModel sharedInstance] uploadNatTable];
}

#pragma mark -- help --
- (IBAction)myHelp:(id)sender
{
    NSString *filePath;
	NSURL *fileURL;
    NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
    
	filePath = [thisBundle pathForResource:@"NATViewHelp" ofType:@"html" inDirectory:PS_HELP_DIRECTORY];
    if (filePath) {
		if ((fileURL = [NSURL fileURLWithPath:filePath])) {
			[[NSWorkspace sharedWorkspace] openURL:fileURL];
		}
	}
}

@end
