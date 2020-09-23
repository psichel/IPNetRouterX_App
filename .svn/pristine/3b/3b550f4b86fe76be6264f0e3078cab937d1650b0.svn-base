//
//  KEVController.h
//  IPNetMonitorX
//
//  Created by psichel on Aug 19 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//
#import <Cocoa/Cocoa.h>
#import "PSServerInterface.h"
#import "PsClient.h"
#import <sys/kern_event.h>
@class KEVSocket;
@class IPHost;

#ifndef KEVNotifications
extern NSString *KEVControllerNotification;
extern NSString *KEVMessageNotification;
//extern NSString *KEVSocketNotification;
#endif

@interface KEVController : NSObject
{
    PsClient*		mClient;
	KEVSocket*		mKEVSocket;
    BOOL			mIsReceiving;
}
+ (KEVController *)sharedInstance;
    // returns a shared instance of the class
- (BOOL)startReceiving;
    // start UDP service
- (void)addObserver:(id)target withSelector:(SEL)method;
    // notify receiver for any UDP received
- (void)removeObserver:(id)target;
- (void)receiveDictionary:(NSDictionary *)dictionary;
@end
