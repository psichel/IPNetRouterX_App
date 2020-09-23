//
//  DiagnosticModel.h
//  IPNetRouterX
//
//  Created by Peter Sichel on 12/7/06.
//  Copyright 2006 Sustainable Softworks. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ipkTypes.h"

@interface DiagnosticModel : NSObject {

KFT_memStat_t memStatArray[kMemStat_last];

}
+ (DiagnosticModel *)sharedInstance;
- (void)receiveMemStatUpdate:(NSData *)messageData;
// Logistics
- (void)addObserver:(id)target withSelector:(SEL)method;
- (void)removeObserver:(id)target;
// NSTableDataSource
- (int)numberOfRowsInTableView:(NSTableView *)tableView;
- (id)tableView:(NSTableView *)tableView
        objectValueForTableColumn:(NSTableColumn *)tableColumn
        row:(int)row;
// Notify listeners when state changes
- (BOOL)updateParameter:(NSString *)name withObject:(id)anObject;
@end

extern NSString *DMNotification;


// table columns
#define kColType		@"type"
#define kColFreeCount	@"freeCount"
#define kColTableCount	@"tableCount"
#define kColAllocated	@"allocated"
#define kColReleased	@"released"
#define kColAllocFailed	@"allocFailed"
#define kColLeaked		@"leaked"
