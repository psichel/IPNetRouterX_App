//
//  AddressScanTable.m
//  IPNetMonitorX
//
//  Created by Peter Sichel on 3/16/09.
//  Copyright 2009 Sustainable Softworks. All rights reserved.
//

#import "AddressScanTable.h"
#import "AddressScanEntry.h"
#import "AddressScanUserInfo.h"

@implementation AddressScanTable

// ---------------------------------------------------------------------------------
//	• tableView:setObjectValue:forTableColumn:row:
// ---------------------------------------------------------------------------------
- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	AddressScanEntry *entry;
	NSString* columnID;
	NSString *key;
	
	entry = [self objectAtIndex:row];
	columnID = [tableColumn identifier];
	[entry setValue:object forKey:columnID];
	// remember user edited values
	if ([columnID isEqualTo:@"Name"]) {
		key = [entry macAddress];
		if ([key length]) {
			[[AddressScanUserInfo sharedInstance] setName:object forKey:key];
		}
	}
	else if ([columnID isEqualTo:@"Comment"]) {
		key = [entry macAddress];
		if ([key length]) {
			[[AddressScanUserInfo sharedInstance] setComment:object forKey:key];
		}

	}
}

@end
