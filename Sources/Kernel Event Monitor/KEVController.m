//
//  KEVController.h
//  IPNetMonitorX
//
//  Created by psichel on Aug 19 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//

#import "KEVSocket.h"
#import "UDPServer.h"
#import "IPNetMessage.h"
#import <sys/ioctl.h>
#import <net/if.h>		// KEV_DL_SUBCLASS

// Globals
NSString *KEVControllerNotification = @"KEVControllerNotification";
NSString *KEVMessageNotification = @"KEVMessageNotification";
//NSString *KEVSocketNotification = @"KEVSocketNotification";
#define KEVNotifications 1
#import "KEVController.h"


@implementation KEVController

//- init and dealloc
+ (KEVController *)sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[KEVController allocWithZone:[self zone]] init];
	}
	return sharedTask;
}

- (id) init {
    if (self = [super init]) {
        mClient = nil;
		mIsReceiving = NO;
        mKEVSocket = nil;
    }
    return self;
}

- (void)dealloc {
    if (mKEVSocket) {
		[mClient abort];	// tell server to stop
        [mClient setCallbackTarget:nil];
		[mClient release];		mClient = nil;
		[mKEVSocket release];
        mKEVSocket = nil;
    }
    [super dealloc];
}

- (BOOL)startReceiving {
    int retval;
    struct kev_request kev_request;
	do {
        if (mIsReceiving) break;	// don't allow multiples        
        // create UDP Server object running as a detached thread
		if (!mClient) {
			mClient = [[PsClient alloc] init];
			[mClient setCallbackTarget:self];
			[mClient setServerClass:[UDPServer class]];
		}
		if (![mClient isConnected]) [mClient createNewServer:[UDPServer class]];
        if ([mClient isConnected]) {
            // get a PF_SYSTEM socket
            if (!mKEVSocket) {
                mKEVSocket = [[KEVSocket alloc] init];
				// Configure the socket to receive the events we're interested in
				kev_request.vendor_code = KEV_VENDOR_APPLE;
				kev_request.kev_class = KEV_NETWORK_CLASS;
				kev_request.kev_subclass = KEV_DL_SUBCLASS;
				retval = ioctl([mKEVSocket socket], SIOCSKEVFILT, (void *)&kev_request);
				if (retval != 0) {
					NSLog(@"KEVSocket failed to set event filter (%s)", strerror(retval));
				}
            }
            if (!mKEVSocket || ([mKEVSocket socket]<0)) {
                NSDictionary* myDictionary;
                myDictionary = [NSDictionary dictionaryWithObject:NSLocalizedString(@"unix socket error",@"unix socket error") forKey:@"statusInfo"];
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:KEVControllerNotification
                    object:self
                    userInfo:myDictionary];
                break;
            }
            // launch service
            [mClient startService:[NSString stringWithFormat:@"udp://%d",[mKEVSocket socket]] withObject:nil];
            mIsReceiving = YES;
        }
    } while (false);
    return mIsReceiving;
}

- (void)addObserver:(id)target withSelector:(SEL)method {
    [[NSNotificationCenter defaultCenter] addObserver:target 
    selector:method 
    name:KEVMessageNotification 
    object:self];
}

- (void)removeObserver:(id)target {
    [[NSNotificationCenter defaultCenter] removeObserver:target
        name:KEVMessageNotification
        object:self];
}


// -- <ControllerFromThread> --
// ---------------------------------
- (oneway void)receiveDictionary:(NSDictionary *)dictionary
// update parameters passed in dictionary
{
	NSEnumerator *enumerator = [dictionary keyEnumerator];
    id key;
    id object;

	if ([[dictionary objectForKey:PSAction] isEqualTo:PSServerFinishedNotification]) {
		if (mKEVSocket) {
			[mKEVSocket release];
			mKEVSocket = nil;
		}
		mIsReceiving = NO;
	}
	
	else {
		while ((key = [enumerator nextObject])) { 
			/* code that uses the returned key */
			if (![key isKindOfClass:[NSString class]]) continue; 
			object = [dictionary objectForKey:key];
			// notify clients
			if ([key isEqualTo:UDPMessageNotification]) {
				// notify listeners with UDP message received
				[[NSNotificationCenter defaultCenter]
					postNotificationName:KEVMessageNotification
					object:self
					userInfo:dictionary];
				YieldToAnyThread();
				break;	// only one message per update
			}
			else {
				// pass any other message as KEVControllerNotification
				// probably a "statusInfo" string
				[[NSNotificationCenter defaultCenter]
					postNotificationName:KEVControllerNotification
					object:self
					userInfo:dictionary];
				break;	// only one item per update
			}
		} // while ((key = [enumerator nextObject]))
	}
}

@end
