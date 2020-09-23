//
//  PSServer.h
//  IPNetMonitorX
//
//  Created by psichel on Wed Oct 17 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Encapsulates setting up a server thread using Distributed Objects (DO)
//  to communicate with an AppKit UI client.
//  Used as base class for network tools.

#import <Foundation/Foundation.h>
#import "PSServerInterface.h"
@class PSURL;


@interface PSServer : NSObject <ThreadFromController> {
    NSConnection*	mConnection;
	id				mController;
	BOOL			mFinishFlag;
	BOOL			mCleanUpFlag;
	BOOL			mKeepRunning;
	// update parameter cache
	NSMutableDictionary* mParameterUpdates;
	
}

+ (void)connectWithPorts:(NSArray *)portArray;
    // This method is invoked on a new thread by the
    // Controller's create thread method.  The portArray contains
    // two NSPort objects that are the ports of the connection
    // to which the new thread should connect to.  The thread
    // connects to these ports, then creates a server object
    // sets it to be its connection's root object.  It then goes
    // into a run loop handling the incoming Distributed Object
    // requests (ie any methods in ThreadFromController).

// Accessors
- (NSConnection *)connection;
- (void)setConnection:(NSConnection *)value;
- (id)controller;
- (void)setController:(id)value;
- (BOOL)keepRunning;
// Thread From Controller
- (oneway void)startService:(NSString *)inURL fromController:(id)controller withObject:(id)object;
- (int)synchStartService:(NSString *)inURL fromController:(id)controller withObject:(id)object;
// controller requests
- (int)parameterDCount;
- (void)updateParameterD:(NSDictionary *)paramaterD;
- (void)updateParameterD:(NSString *)name withObject:(id)object;
- (BOOL)updateParameter:(NSString *)name withObject:(id)object;
- (void)reportError:(NSString *)text withCode:(int)code;
- (BOOL)didUserAbort;
- (void)finish;
- (void)cleanUp;

// server functions
- (int)serverStart:(NSDictionary *)plist;
- (int)serverStop:(NSDictionary *)plist;
- (int)serverApply:(NSDictionary *)plist;
- (int)serverShowActive:(NSDictionary *)plist;
- (int)serverTerminate:(NSDictionary *)plist;

@end

// dictionary key for request
#define kServerRequest		@"serverRequest"
// common requests
#define kServerStart		@"start"
#define kServerStop			@"stop"
#define kServerApply		@"applySettings"
#define kServerShowActive   @"reportState"
#define kServerDisconnect	@"disconnect"
#define kServerTerminate	@"terminate"
