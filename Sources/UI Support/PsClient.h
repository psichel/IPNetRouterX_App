//
//  PsClient.h
//  IPNetMonitorX
//
//  Created by psichel on Wed Oct 17 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Encapsulates setting up a Distributed Objects (DO) server thread
//  from an AppKit UI client.
//
// <previous design>
//  Since Obj-C doesn't have multiple inheritance, we copy and paste these
//  methods into our window controller classes.
// <new design>
//  Since Obj-C doesn't have multiple inheritance,
//  we design this as a stand-alone DO controller class
//  to be used as a client-server go-between.

#import <Foundation/Foundation.h>
#import "PSServerInterface.h"
#import "NSDate_Extensions.h"


@interface PsClient : NSObject <ControllerFromThread> {
//	id			mServer;	// for code cleanup *** remove when done
	Class		serverClass;
	id			remoteServer;
	id			callbackTarget;
	BOOL		abortFlag;
	NSDate*		lastAbortCheck;		// remember time of last didUserAbort
	NSTimer*	abortTimer;
}
// create and kill servers
- (BOOL)createNewServer:(Class)serverClass;
- (void)killServer;
- (void)connectionDidDie:(NSNotification *)aNotification;
//- (void)receiveNotification:(NSNotification *)aNotification
// client interface
- (int)startService:(NSString *)inURL withObject:(id)object;
- (int)synchStartService:(NSString *)inURL withObject:(id)object;
- (BOOL)updateParameter:(NSString *)name withObject:(id)object;
- (BOOL)abort;
- (BOOL)abortWithTimeout:(NSTimeInterval)timeInterval;
- (void)abortTimeout:(id)timer;

// ControllerFromThread
//- (oneway void)receiveDictionary:(NSDictionary *)dictionary;
//- (BOOL)didUserAbort;

// accessors
- (BOOL)isConnected;
- (void)setServerClass:(Class)value;
- (void)setRemoteServer:(id)value;
- (void)setCallbackTarget:(id)value;
- (NSDate *)lastAbortCheck;

@end
