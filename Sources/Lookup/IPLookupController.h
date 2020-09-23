//
//  IPLookupController.h
//  IPNetMonitorX
//
//  Created by psichel on Wed Nov 14 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Encapsulates launching a thread to perform DNS lookups.
//  Uses NSNotification to callback the client when a lookup has completed.
//
#import <Cocoa/Cocoa.h>
#import "PSServerInterface.h"
#import "PsClient.h"

@interface IPLookupController : NSObject
{
    PsClient*		mClient;
	BOOL			mRequestInProgress;
    NSString*		mResultString;
	int				mOption;

	NSDictionary*	mLookupRequest;
	NSMutableArray* mLookupQueue;
}
// accessors
- (NSString *)result;
- (void)setResult:(NSString *)aString;
- (NSDictionary *)lookupRequest;
- (void)setLookupRequest:(NSDictionary *)value;
- (int)option;
- (void)setOption:(int)value;

// actions
- (BOOL)lookup:(NSString *)aString callbackObject:(id)target
    withSelector:(SEL)method
    userInfo:(NSDictionary *)aDictionary;
- (BOOL)doRequest:(NSDictionary *)lookupRequest;
- (void)testComplete;
- (void)abort;
- (BOOL)ready;
- (void)notifyClient:(NSDictionary *)lookupRequest withObject:(NSString *)value;
@end

#define kIPLookupControllerNotification @"IPLookupControllerNotification"

// use lookupRequest dictionary to queue requests
#define kLookup_string		@"string"
#define kLookup_target		@"target"
#define kLookup_selectorNum	@"selectorNum"
#define kLookup_userInfo	@"userInfo"

// options
#define kOption_none		0
#define kOption_resultOnly	1
