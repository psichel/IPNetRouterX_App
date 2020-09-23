//
//  AlternateRouteModel.h
//  IPNetRouterX
//
//  Created by Peter Sichel on 1/4/07.
//  Copyright (c) 2007 Sustainable Softworks. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AlternateRouteTable.h"
@class SentryState;

extern NSString* AlternateRouteNotification;

@interface AlternateRouteModel : NSObject {
	SentryState *sentryState;
	AlternateRouteTable *alternateRouteTable;
}
+ (AlternateRouteModel *) sharedInstance;

// save & restore
- (void)loadModelFromSaveDictionary:(NSDictionary *)saveDictionary;
- (void)saveModelToSaveDictionary:(NSMutableDictionary *)saveDictionary;

// accessors
- (AlternateRouteTable *)alternateRouteTable;
- (void)setAlternateRouteTable:(AlternateRouteTable *)value;

// actions
- (void)alternateRouteSave;
- (void)alternateRouteRevert;
- (void)alternateRouteApply;

// observer interface
- (void)addObserver:(id)target withSelector:(SEL)method;
- (void)removeObserver:(id)target;
// Notify listeners when state changes
- (BOOL)updateParameter:(NSString *)name withObject:(id)anObject;

// receive data
- (void)receiveRouteUpdate:(NSData *)messageData;

// NSTableDataSource
- (int)numberOfRowsInTableView:(NSTableView *)tableView;
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row;
// optional
- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row;
- (void)doInterface:(NSString *)interface forRow:(int)row;

@end

#define SS_alternateRouteTable		@"alternateRouteTable"
#define SS_alternateRouteItem		@"alternateRouteItem"
