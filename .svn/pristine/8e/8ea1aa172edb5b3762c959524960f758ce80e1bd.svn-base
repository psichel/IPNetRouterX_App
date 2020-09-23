//
//  PSToolState.h
//  IPNetSentryX
//
//  Created by Peter Sichel on 2007-10-18
//  Copyright (c) 2007 Sustainable Softworks, Inc. All rights reserved.
//
//  Base class for maintaining tool state as a mutable dictionary
//  for easy storage and retrieval, and notifying listeners when
//  state changes.

#import <Foundation/Foundation.h>

extern NSString* PSToolStateNotification;

@interface PSToolState : NSObject {		
    // Store state variables (model) in a mutable dictionary to simplify
    // coding and decoding interface entries.
    NSMutableDictionary* nodeDictionary;
	id delegate;

    // Since each variable is an object with a standard accessor,
    // we can adopt standard NSKeyValueCoding
}

// observers
- (void)addObserver:(id)target withSelector:(SEL)method;
- (void)removeObserver:(id)target;
// Notify listeners when state changes
- (BOOL)updateParameter:(NSString *)name withObject:(id)anObject;
- (BOOL)updateParameterCD:(NSString *)name withObject:(id)anObject;
@end

#define TS_documentChangeDone		@"documentChangeDone"
