//
//  PSPropertyValue.h
//  IPNetMonitorX
//
//  Created by psichel on Tue Oct 28 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.
//
//  Encapsulates Property Values used as a data source for a Combo Box

#import <Foundation/Foundation.h>
#import <AppKit/NSComboBox.h>
@class FilterEntry;

#define ListSize	10

@interface PSPropertyValue : NSObject {
    NSMutableArray* currentArray;
    NSMutableDictionary* valueDictionary;
}
- (id)init;
- (void)dealloc;
- (void)loadDictionary;
- (void)resetDictionary;
// save and restore values for current property
- (void)saveWithKey:(NSString *)key;
- (void)restoreWithKey:(NSString *)key;
// expand values
- (void)expandEntry:(FilterEntry *)entry;
- (NSString *)expandProperty:(int)propertyID value:(NSString *)value;
// access
- (NSArray *)selectProperty:(int)propertyID;
- (int)addObject:(NSString *)entry;
- (void)addObjects:(NSArray *)theArray;
- (BOOL)removeObject:(NSString *)entry;
- (BOOL)removeObjectAtIndex:(int)index;
- (NSString *)objectAtIndex:(int)index;
- (BOOL)replaceObjectAtIndex:(int)index withObject:(NSString *)entry;
- (unsigned)count;
// datasource
#if 0
- (int)numberOfItemsInComboBox:(NSComboBox *)aComboBox;
- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(int)index;
- (unsigned int)comboBox:(NSComboBox *)aComboBox indexOfItemWithStringValue:(NSString *)string;
- (NSString *)comboBox:(NSComboBox *)aComboBox completedString:(NSString *)string;
#else
- (int)numberOfItemsInComboBoxCell:(NSComboBoxCell *)comboBoxCell;
- (id)comboBoxCell:(NSComboBoxCell *)aComboBoxCell objectValueForItemAtIndex:(int)index;
- (unsigned int)comboBoxCell:(NSComboBoxCell *)aComboBoxCell indexOfItemWithStringValue:(NSString *)string;
- (NSString *)comboBoxCell:(NSComboBoxCell *)aComboBoxCell completedString:(NSString *)uncompletedString; 
#endif
@end

#define PID_interface	@"interface"
#define PID_direction	@"direction"
#define PID_netNumber	@"netNumber"
#define PID_MACAddress	@"MACAddress"
#define PID_protocol	@"protocol"
#define PID_IPFragmentOffset	@"IPFragmentOffset"
#define PID_IPOptions	@"IPOptions"
#define PID_TCPHeaderFlags	@"TCPHeaderFlags"
#define PID_TCPOptions	@"TCPOptions"
#define PID_portNumber	@"portNumber"
#define PID_include		@"include"
#define PID_URLKeyword	@"URLKeyword"
#define PID_timeOfDay	@"timeOfDay"
#define PID_dayOfWeek	@"dayOfWeek"
#define PID_dateAndTime	@"dateAndTime"
#define PID_dataContent	@"dataContent"
#define PID_ICMPType	@"ICMPType"
#define PID_ICMPCode	@"ICMPCode"

