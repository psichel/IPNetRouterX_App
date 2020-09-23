//
//  PSToolState.m
//  IPNetSentryX
//
//  Created by Peter Sichel on 2007-10-18
//  Copyright (c) 2007 Sustainable Softworks, Inc. All rights reserved.
//
//  Base class for maintaining tool state as a mutable dictionary
//  for easy storage and retrieval, and notifying listeners when
//  state changes.

#import "PSToolState.h"

// Globals
NSString *PSToolStateNotification = @"PSToolStateNotification";

@implementation PSToolState

// ---------------------------------------------------------------------------------
//	¥ init
// ---------------------------------------------------------------------------------
- (id)init
{
    if (self = [super init]) {
        // initialize our instance variables
        nodeDictionary = [[NSMutableDictionary alloc] initWithCapacity:64];
        if (!nodeDictionary) return nil;
	}
    return self;
}
// ---------------------------------------------------------------------------------
//	¥ dealloc
// ---------------------------------------------------------------------------------
- (void) dealloc {
	// release dictionaries we allocated
	[nodeDictionary release]; nodeDictionary = nil;	
    [super dealloc];
}

// ---------------------------------------------------------------------------------
//	¥ addObserver
// ---------------------------------------------------------------------------------
- (void)addObserver:(id)target withSelector:(SEL)method {
	[[NSNotificationCenter defaultCenter] addObserver:target 
    selector:method 
    name:PSToolStateNotification 
    //object:self];
    object:nil];
}

// ---------------------------------------------------------------------------------
//	¥ removeObserver
// ---------------------------------------------------------------------------------
- (void)removeObserver:(id)target {
    [[NSNotificationCenter defaultCenter] removeObserver:target
        name:PSToolStateNotification
        //object:self];
		object:nil];
}

// ---------------------------------------------------------------------------------
//	¥ updateParameter
// ---------------------------------------------------------------------------------
// Notify listeners when state changes
- (BOOL)updateParameter:(NSString *)name withObject:(id)anObject
{
	BOOL returnValue = NO;
	if (name && anObject) {
		NSDictionary* myDictionary;
		myDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:anObject, name, nil];
		// notify listeners with dictionary
		[[NSNotificationCenter defaultCenter]
			postNotificationName:PSToolStateNotification
			object:self
			userInfo:myDictionary];		
		[myDictionary release];
		returnValue = YES;
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ updateParameterCD
// ---------------------------------------------------------------------------------
// Notify listeners when state changes and signal document change done
- (BOOL)updateParameterCD:(NSString *)name withObject:(id)anObject
{
	BOOL returnValue = NO;
	if (name && anObject) {
		NSDictionary* myDictionary;
		myDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:anObject, name,
			TS_documentChangeDone, [NSNumber numberWithInt:NSChangeDone],
			nil];
		// notify listeners with dictionary
		[[NSNotificationCenter defaultCenter]
			postNotificationName:PSToolStateNotification
			object:self
			userInfo:myDictionary];		
		[myDictionary release];
		returnValue = YES;
	}
	return returnValue;
}

@end
