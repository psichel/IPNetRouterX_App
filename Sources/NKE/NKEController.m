//
//  NKEController.m
//  IPNetSentryX
//
//  Created by psichel on 2007-10-22.
//  Copyright (c) 2007 Sustainable Softworks. All rights reserved.
//
//  Encapsulates connecting to IPNetSentry_NKE
//
#import "NKEController.h"
#import "AppSupport.h"
#import "PSToolState.h"		// PSToolStateNotification
#import PS_TNKE_INCLUDE
#import "IPUDPSocket.h"
#import <sys/socket.h>
#import <sys/socketvar.h>
#import <arpa/inet.h>

#import "PsClient.h"
#import "UDPServer.h"
#import "IPNetMessage.h"


#if 0
#import "SentryController.h"
//#import <Foundation/Foundation.h>
#import "IPValue.h"
#import "IPValueFormatter.h"
#import "IPSupport.h"
#import "HardwareAddress.h"
#import "NSDate_Extensions.h"
#import "AppDelegate.h"
#import "FilterEntry.h"
#import "InterfaceEntry.h"
#import "PSURL.h"
#import "ICMPController.h"
#import "kft.h"
#endif

// global system version info obtained during app startup
extern int gMajorVersion, gMinorVersion, gMinorMinorVersion;

@interface NKEController (PrivateMethods)
- (BOOL)startReceiving:(NSString *)socketName from:(id)receiveTarget;
@end

@implementation NKEController

+ (NKEController *)sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[NKEController alloc] init];
	}
	return sharedTask;
}

// ---------------------------------------------------------------------------------
//	• init
// ---------------------------------------------------------------------------------
- (NKEController *)init {
    if (self = [super init]) {
        // initialize our instance variables
		mConnected = NO;
        mIPKSocket = nil;
		mUDPClient = nil;
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	• dealloc
// ---------------------------------------------------------------------------------
- (void)dealloc {
	[self disconnect];
	[super dealloc];
}

// ---------------------------------------------------------------------------
//	• disconnect
// ---------------------------------------------------------------------------
- (int)disconnect {
	int returnValue = 0;
	
	if (mConnected) {
		mConnected = NO;
		returnValue = [self setOption:SO_MONITOR_OFF param:NULL size:0];
		if (returnValue) {
			//[self updateParameter:@"statusInfo" withObject:NSLocalizedString(@"NKE detach failure",@"NKE detach failure")];
		}
		// stop receiving
		if ([mUDPClient isConnected]) {
			// tell server to stop
			[mUDPClient abortWithTimeout:2.0];
			// disconnect above should close UDP Socket listening for NKE messages
			// could signal corresponding socket to abort (mAbortFD)
		}
		// release our control socket since NKE might unload!
        [mIPKSocket release];	mIPKSocket = nil;
		// give server a chance to terminate (read loop should exit when socket above is closed)
		[NSThread  sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
		if (!returnValue) [self updateParameter:@"statusInfoAppend" withObject:@" Disconnected"];
		// release UDP client (if not already)
		[mUDPClient setCallbackTarget:nil];
		[mUDPClient release];   mUDPClient = nil;
	}
	return returnValue;
}

// ---------------------------------------------------------------------------
//	• connectToNKE
// ---------------------------------------------------------------------------
//	Setup control channel to NKE by loading if needed and inserting as a socket
//	filter in our controlling UDP socket.
- (int)connectToNKEFrom:(id)receiveTarget {
	int returnValue = 0;
	BOOL fileExists;
	so_nke_t myNKE;
	// don't allow multiples
	if (!mConnected) do {
		// get UDP socket
		if (!mIPKSocket) {
			mIPKSocket = [[IPUDPSocket alloc] init];
			returnValue = [mIPKSocket socket];
			if (returnValue <= 0) break;
		}
		// connect to our NKE
            // tell the kernel to find and insert our NKE in our socket
        #ifdef IPNetRouter
			myNKE.nke_handle = IPNetRouter_TNKE_Handle;
        #else
			myNKE.nke_handle = IPNetSentry_TNKE_Handle;
        #endif
        myNKE.nke_where = 0;
        myNKE.nke_flags = NFF_AFTER;
			// dont call [self setOption...] to avoid looping
        returnValue = [mIPKSocket setSO:SO_NKE param:&myNKE size:sizeof(myNKE)];
        if (returnValue) {
            // NKE might not be loaded, try to load it
            NSString* toolPath;
            NSString* nkePath;
            // get tool path
            toolPath = [AppSupport toolPathForName:@"LoadNKE" fileExists:&fileExists];
			if (!fileExists) {
				NSLog(@"Helper tool LoadNKE was not found at path: %@",toolPath);
				returnValue = -1;
				break;
			}
			// get NKE path
			nkePath = [AppSupport toolPathForName:ps_kext_name fileExists:&fileExists];
			if (!fileExists) {
				NSLog(@"NKE was not found at path: %@",nkePath);
				returnValue = -1;
				break;
			}
			// run tool to load our NKE
            int retry = 3;
			returnValue = [AppSupport doTask:toolPath
                arguments:[NSArray arrayWithObjects:@"-load", nkePath, nil] output:nil];
			while (returnValue && (retry > 0)) {
				// pause and try again
				retry -= 1;
				[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval)0.2] ];
				returnValue = [AppSupport doTask:toolPath
					arguments:[NSArray arrayWithObjects:@"-load", nkePath, nil] output:nil];
			}


            // try again to contact our NKE
            returnValue = [self setOption:SO_NKE param:&myNKE size:sizeof(myNKE)];
            if (returnValue) {
                [self updateParameter:@"statusInfo" withObject:
					NSLocalizedString(@"Failed to connect with NKE, possible loading or authentication error.",@"Failed to connect with NKE, possible loading or authentication error.")];
				break;
            }
        }
		// set up a receiver
		[self startReceiving:[NSString stringWithFormat:@"%d",[mIPKSocket socket]] from:receiveTarget];
		// remember we tried this
		mConnected = YES;
		[self updateParameter:@"statusInfoAppend" withObject:@"  Connected"];
 	} while (FALSE);
	return returnValue;
}

// ---------------------------------------------------------------------------
//	• sentryAttach
// ---------------------------------------------------------------------------
- (int)sentryAttach:(KFT_interfaceEntry_t *)kftInterfaceEntry
{
    int returnValue = 0;
    sopt_attachParam_t attachParam;
       
    do {
        // check control channel to NKE
        if (!mConnected) {
			[self updateParameter:@"statusInfo" withObject:@"Attach failed, not connected"];
			break;
		}
		memcpy(&attachParam.kftInterfaceEntry, kftInterfaceEntry, sizeof(KFT_interfaceEntry_t));
        // ask NKE to attach to corresponding interface
        returnValue = [self setOption:SO_ATTACH_LINK param:&attachParam size:sizeof(attachParam)];
		if (returnValue) {
			[self updateParameter:@"statusInfoAppend"
				withObject:[NSString stringWithFormat:@"  Attach %s failed",kftInterfaceEntry->bsdName]];
		}
		else [self updateParameter:@"statusInfoAppend" withObject:
			[NSString stringWithFormat:@"  Attached %s",kftInterfaceEntry->bsdName]];
	} while (FALSE);
	return returnValue;
}

// ---------------------------------------------------------------------------
//	• sentryDetach
// ---------------------------------------------------------------------------
- (int)sentryDetach:(KFT_interfaceEntry_t *)kftInterfaceEntry
{
    int returnValue = 0;
    sopt_attachParam_t attachParam;
       
    do {
        // check control channel to NKE
         if (!mConnected) {
			[self updateParameter:@"statusInfo" withObject:@"Detach failed, not connected"];
			break;
		}
		memcpy(&attachParam.kftInterfaceEntry, kftInterfaceEntry, sizeof(KFT_interfaceEntry_t));
        // ask NKE to detach from corresponding interface or all interfaces if name is "any"
		if (strncmp(kftInterfaceEntry->bsdName, "any", 3) == 0) 
			returnValue = [self setOption:SO_DETACH_LINK param:&attachParam size:0];
		else
			returnValue = [self setOption:SO_DETACH_LINK param:&attachParam size:sizeof(attachParam)];
		if (returnValue) {
			if (returnValue == ENOENT) {
				// don't need to show this since state didn't change
				//[self updateParameter:@"statusInfoAppend"
				//	withObject:[NSString stringWithFormat:@"  Not attached to %s",kftInterfaceEntry->bsdName]];
			}
			else {			
				[self updateParameter:@"statusInfoAppend"
					withObject:[NSString stringWithFormat:@"  Detach %s failed %s",kftInterfaceEntry->bsdName, strerror(returnValue)]];
			}
		}
		else {
			[self updateParameter:@"statusInfoAppend" withObject:
				[NSString stringWithFormat:@"  Detached %s",kftInterfaceEntry->bsdName]];
		}
	} while (FALSE);
	return returnValue;
}


// ---------------------------------------------------------------------------
//	• setMessageMask
// ---------------------------------------------------------------------------
- (int)setMessageMask:(u_int32_t)messageMask
{
	int returnValue = -1;
	sopt_flagsParam_t flagsParam;
	
	// check control channel to NKE
	 if (!mConnected) {
		[self updateParameter:@"statusInfo" withObject:@"setMessageMask failed, not connected"];
	}
	else {
		flagsParam.flags = messageMask;
		flagsParam.mask = messageMask;
		// set flags in NKE
		returnValue = [self setOption:SO_SET_MESSAGEMASK param:&flagsParam size:sizeof(sopt_flagsParam_t)];
		// report result
		if (returnValue) {
			[self updateParameter:@"statusInfo"
				withObject:[NSString stringWithFormat:@"Set MessageMask failure: %s", strerror(returnValue)]];
		}
	}
	return returnValue;
}

// ---------------------------------------------------------------------------
//	• getMessageMask
// ---------------------------------------------------------------------------
- (int)getMessageMask
{
    int returnValue = -1;
	int status;
	sopt_flagsParam_t flagsParam;
       
	// check control channel to NKE
	 if (!mConnected) {
		[self updateParameter:@"statusInfo" withObject:@"getMessageMask failed, not connected"];
	}
	else {
		// get flags in NKE
		unsigned size = sizeof(sopt_flagsParam_t);
		bzero(&flagsParam, size);
		// get flags in NKE
		status = [self getOption:SO_SET_MESSAGEMASK param:&flagsParam size:&size];
		// report result
		if (status) {
			[self updateParameter:@"statusInfo"
				withObject:[NSString stringWithFormat:@"Set Flags failure: %s", strerror(status)]];
		}
		else returnValue = flagsParam.flags;
	}
	return returnValue;
}


// ---------------------------------------------------------------------------
//	• setFlags
// ---------------------------------------------------------------------------
- (int)setFlags:(u_int32_t)flags
{
	int returnValue = -1;
	sopt_flagsParam_t flagsParam;
	
	// check control channel to NKE
	 if (!mConnected) {
		[self updateParameter:@"statusInfo" withObject:@"setMessageMask failed, not connected"];
	}
	else {
		flagsParam.flags = flags;
		flagsParam.mask = flags;
		// set flags in NKE
		returnValue = [self setOption:SO_SET_FLAGS param:&flagsParam size:sizeof(sopt_flagsParam_t)];
		// report result
		if (returnValue) {
			[self updateParameter:@"statusInfo"
				withObject:[NSString stringWithFormat:@"Set MessageMask failure: %s", strerror(returnValue)]];
		}
	}
	return returnValue;
}

// ---------------------------------------------------------------------------
//	• clearFlags
// ---------------------------------------------------------------------------
- (int)clearFlags:(u_int32_t)flags
{
	int returnValue = -1;
	sopt_flagsParam_t flagsParam;
	
	// check control channel to NKE
	 if (!mConnected) {
		[self updateParameter:@"statusInfo" withObject:@"setMessageMask failed, not connected"];
	}
	else {
		flagsParam.flags = 0;
		flagsParam.mask = flags;
		// set flags in NKE
		returnValue = [self setOption:SO_SET_FLAGS param:&flagsParam size:sizeof(sopt_flagsParam_t)];
		// report result
		if (returnValue) {
			[self updateParameter:@"statusInfo"
				withObject:[NSString stringWithFormat:@"Set MessageMask failure: %s", strerror(returnValue)]];
		}
	}
	return returnValue;
}


#pragma mark -- send/receive --
// ---------------------------------------------------------------------------
//	• isConnected
// ---------------------------------------------------------------------------
- (BOOL)isConnected { return mConnected; }

// ---------------------------------------------------------------------------
//	• setOption
// ---------------------------------------------------------------------------
- (int)setOption:(int)option param:(void *)param size:(unsigned)size
{
	int returnValue;
	// send to NKE
	returnValue = [mIPKSocket setSO:option param:param size:size];
	return returnValue;
}

// ---------------------------------------------------------------------------
//	• getOption
// ---------------------------------------------------------------------------
- (int)getOption:(int)option param:(void *)param size:(unsigned *)size
{
	int returnValue;
	// send to NKE
	returnValue = [mIPKSocket getSO:option param:(void *)param size:size];
	return returnValue;
}

// ---------------------------------------------------------------------------
//	• startReceiving
// ---------------------------------------------------------------------------
- (BOOL)startReceiving:(NSString *)socketName from:(id)receiveTarget {
    BOOL returnValue = NO;
	
	if (!mUDPClient) {
        // create UDP Server object running as a detached thread
		mUDPClient = [[PsClient alloc] init];
		[mUDPClient setCallbackTarget:receiveTarget];
		[mUDPClient setServerClass:[UDPServer class]];
        [mUDPClient createNewServer:[UDPServer class]];
        if ([mUDPClient isConnected]) {
            // launch service
            [mUDPClient startService:[NSString stringWithFormat:@"udp://%@",socketName] withObject:nil];
			returnValue = YES;
        }
		else {
			[self updateParameter:@"statusInfo" withObject:@"Failure creating UDP server"];
		}
    }
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	• receiveDictionary:
// ---------------------------------------------------------------------------------
- (void)receiveDictionary:(NSDictionary *)dictionary
// update parameters passed in dictionary
// Uses key as the name of a class or instance and sets its value
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSEnumerator* enumerator;
    id key;
	
	if ([[dictionary objectForKey:PSAction] isEqualTo:PSServerFinishedNotification]) {
		// release DO clients
		// so we can get new ones
		// release UDP client (if not already)
		[mUDPClient setCallbackTarget:nil];
		[mUDPClient release];   mUDPClient = nil;
		//[[NKEController sharedInstance] disconnect];
	}
	
	if ([[dictionary objectForKey:PSAction] isEqualTo:PSReportErrorNotification]) {
		int code;
		code = [[dictionary objectForKey:@"code"] intValue];
		if (code == ENOENT) {
			// don't cancel on wake from sleep unless you have a plan to resume
		}
	}
	else {
		enumerator = [dictionary keyEnumerator];
		while ((key = [enumerator nextObject])) { 
			/* code that uses the returned key */
			if (![key isKindOfClass:[NSString class]]) continue; 
			if ([key isEqualTo:UDPMessageNotification]) {
				IPNetMessage* message;
				ipk_message_t* ipkMessage;
				// dispatch message
				message = [dictionary objectForKey:key];
				ipkMessage = (ipk_message_t *)[[message data] bytes];
				
				switch (ipkMessage->type) {
					case kFilterUpdate:
					break;
				}
			}
		}
	}
	[pool release];
}

#pragma mark -- support --
// ---------------------------------------------------------------------------------
//	• addObserver
// ---------------------------------------------------------------------------------
- (void)addObserver:(id)target withSelector:(SEL)method {
	[[NSNotificationCenter defaultCenter] addObserver:target 
    selector:method 
    name:PSToolStateNotification 
    //object:self];
    object:nil];
}

// ---------------------------------------------------------------------------------
//	• removeObserver
// ---------------------------------------------------------------------------------
- (void)removeObserver:(id)target {
    [[NSNotificationCenter defaultCenter] removeObserver:target
        name:PSToolStateNotification
        //object:self];
		object:nil];
}

// ---------------------------------------------------------------------------------
//	• updateParameter
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

@end
