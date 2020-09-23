//
//  PSServer.m
//  IPNetMonitorX
//
//  Created by psichel on Wed Oct 17 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Encapsulates setting up a server thread using Distributed Objects (DO)
//  to communicate with an AppKit UI client.
//  Used as base class for network tools.

#import "PSServer.h"
#import "PSURL.h"
#import "NSException_Extensions.h"

@implementation PSServer
- init
{
    if (self = [super init]) {
		// initialize our instance variables
		mConnection = nil;
		mController = nil;
		mFinishFlag = NO;
		mCleanUpFlag = NO;
		mKeepRunning = YES;
		mParameterUpdates = nil;
    }
    return self;
}

- (void) dealloc {
    [mParameterUpdates release];	mParameterUpdates = nil;
	[super dealloc];
}


+ (void)connectWithPorts:(NSArray *)portArray
    // See comments in implementation part.
{
    NSAutoreleasePool *pool;
    NSConnection *connectionToController;
    id threadObject;

    // First we must create an autorelease pool.  Methods that we invoke
    // are going to expect to be able to do [object autorelease], but this
    // doesn't work unless we explicitly create an autorelease pool because
    // we're running in a new thread, and threads don't start off with a
    // default autorelease pool.
    
    pool = [[NSAutoreleasePool alloc] init];

    // Now we connect back to the main thread using the ports given in our
    // portArray argument.  Note the subtle difference in that we use
    // connectWithReceivePort here, whereas Controller's init method uses
    // initWithReceivePort.
    
    connectionToController = [NSConnection
        connectionWithReceivePort:[portArray objectAtIndex:0]
        sendPort:[portArray objectAtIndex:1]];

	// enabe multiple threads to use this connection for timer based actions
	[connectionToController enableMultipleThreads];

    // Now create a thread object.  In this example, we only have one thread
    // object to handle all requests.
    
    threadObject = [[self alloc] init];
    
    // Now set this object as the root object for the connection we just made
    // to the controller.  We do this so that the controller can call us
    // to invoke one or more methods
    [connectionToController setRootObject:threadObject];

	// save our connection as an instance variable so we can kill ourself later
	[threadObject setConnection:connectionToController];

    // We now release our server object, so the controller has the only reference
    // to it.  Well, actually, the NSConnection also has a reference to it,
    // which is what keeps the object around until the main thread picks it up.
    
//    [threadObject release];

	// set signal action to ignore interrupts
	signal(SIGINT, SIG_IGN);
	signal(SIGPIPE, SIG_IGN);
	
    // Now we enter our run loop.  The run loop waits looking for events and
    // executes them.  In the case of a non-application thread, the source
    // of events is the NSConnections installed in the loop.  In our case, this
    // is the NSConnection we created earlier in this routine.  When a DO
    // message arrives on our receive port, the run loop unpackages the message
    // and executes the corresponding Objective-C method.

	@try {        
		//[[NSRunLoop currentRunLoop] run];
		while ([threadObject keepRunning] &&
			[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
	}
	@catch( NSException *theException ) {
		if (![[theException name] isEqualTo:NSInternalInconsistencyException]) [theException printStackTrace];
	}
		
    
    // give threadObject a chance to cleanup when server is killed
        // retain count is unpredictable
    [threadObject cleanUp];
    [threadObject release];
    
    // Clean up.
    [pool release];
}

// Accessors
- (NSConnection *)connection { return mConnection; }
- (void)setConnection:(NSConnection *)value {
	mConnection = value;
}

- (id)controller { return mController; }
- (void)setController:(id)value {
	[value retain];
	[mController release];
	mController = value;
}

- (BOOL)keepRunning { return mKeepRunning; }

// ===========================================================================
// ThreadFromController
// ===========================================================================
// ---------------------------------------------------------------------------------
//	¥ startService:
// ---------------------------------------------------------------------------------
- (oneway void)startService:(NSString *)inURL fromController:(id)controller withObject:(id)anObject
{
	[self synchStartService:inURL fromController:controller withObject:anObject];
}

// ---------------------------------------------------------------------------
//	¥ synchStartService:fromController:withObject:
// ---------------------------------------------------------------------------
// WARNING
// This method should not be used by a remote client if the server is already
// running and can possibly make two-way blocking call (such as "didUserAbort")
// to the client thread as this could result in a deadlock with each thread
// waiting for the other to respond.
- (int)synchStartService:(NSString *)inURL fromController:(id)controller withObject:(id)anObject
{
	// override to perform thread services
	int result = 0;
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSString* str = nil;

	@try {    
		// The following line is an interesting optimisation.  We tell our proxy
		// to the controller object about the methods that we're going to
		// send to the proxy.    
		[controller setProtocolForProxy:@protocol(ControllerFromThread)];
		// init method vars
		[self setController:controller];

		// extract parameters
		str = inURL;
		if (!str) str = [(NSDictionary *)anObject objectForKey:kServerRequest];
		// dispatch commands
		if (mFinishFlag) {
			[self reportError:NSLocalizedString(@"Server is terminating",@"Server is terminating") withCode:0];
		}
		else if ([str hasPrefix:kServerStart])
			result = [self serverStart:anObject];
		else if ([str hasPrefix:kServerStop])
			result = [self serverStop:anObject];
		else if ([str hasPrefix:kServerTerminate])
			result = [self serverTerminate:anObject];
		else if ([str hasPrefix:kServerApply])
			result = [self serverApply:anObject];
		else if ([str hasPrefix:kServerShowActive])
			result = [self serverShowActive:anObject];
		else {
			[self updateParameter:@"statusInfo" withObject:NSLocalizedString(@"Target not recognized",@"Target not recognized")];
		}
	}
	@catch( NSException *theException ) {
		NSString* statusInfo = @"Exception during PSServer.m -synchStartService";
		NSLog(@"%@",statusInfo);
		[self updateParameter:@"statusInfo" withObject:statusInfo];
		if (str) NSLog(@"%@",str);
		// try to print symbolic stack trace
		[theException printStackTrace];
	}

    [pool release]; pool = nil;
	return result;
}

// ---------------------------------------------------------------------------------
//	¥ serverStart:
// ---------------------------------------------------------------------------------
- (int)serverStart:(NSDictionary *)plist
{
	return 0;
}

// ---------------------------------------------------------------------------------
//	¥ serverStop:
// ---------------------------------------------------------------------------------
- (int)serverStop:(NSDictionary *)plist
{
	return 0;
}

// ---------------------------------------------------------------------------------
//	¥ serverApply:
// ---------------------------------------------------------------------------------
- (int)serverApply:(NSDictionary *)plist
{
	return 0;
}

// ---------------------------------------------------------------------------------
//	¥ serverShowActive:
// ---------------------------------------------------------------------------------
- (int)serverShowActive:(NSDictionary *)plist
{
	return 0;
}

// ---------------------------------------------------------------------------------
//	¥ serverTerminate:
// ---------------------------------------------------------------------------------
- (int)serverTerminate:(NSDictionary *)plist
{
	[self finish];
	return 0;
}


// ===========================================================================
// ControllerFromThread support methods
// ===========================================================================

// ---------------------------------------------------------------------------
//	¥ parameterDCount
// ---------------------------------------------------------------------------
- (int)parameterDCount
{
	int count = [mParameterUpdates count];
	return (count);
}

// ---------------------------------------------------------------------------
//	¥ updateParameterD:
// ---------------------------------------------------------------------------
- (void)updateParameterD:(NSDictionary *)parameterD
{
	// allocate dictionary if needed
	if (!mParameterUpdates) mParameterUpdates = [[NSMutableDictionary alloc] initWithCapacity:20];
	// set object in pre-allocated dictionary cache to reduce overhead
	if (parameterD) {
		[mParameterUpdates addEntriesFromDictionary:parameterD];
	}
}

// ---------------------------------------------------------------------------
//	¥ updateParameterD:withObject:
// ---------------------------------------------------------------------------
// update parameter Dictionary, but don't sent it yet
- (void)updateParameterD:(NSString *)name withObject:(id)object
{
	// allocate dictionary if needed
	if (!mParameterUpdates) {
		mParameterUpdates = [[NSMutableDictionary alloc] initWithCapacity:20];
	}
	// set object in pre-allocated dictionary cache to reduce overhead
	if (name && object) {
		[mParameterUpdates setObject:object forKey:name];
	}
}

// ---------------------------------------------------------------------------
//	¥ updateParameter:withObject:
// ---------------------------------------------------------------------------
// update parameter Dictionary and send it now
- (BOOL)updateParameter:(NSString *)name withObject:(id)object
{
	BOOL returnValue = YES;
	// allocate dictionary if needed
	if (!mParameterUpdates) mParameterUpdates = [[NSMutableDictionary alloc] initWithCapacity:20];
	// set object in pre-allocated dictionary cache to reduce overhead
	if (name && object) {
		[mParameterUpdates setObject:object forKey:name];
	}
	if ([mParameterUpdates count]) {
		// remote object might have gone away, so check for exceptions
		@try {
			[mController receiveDictionary:mParameterUpdates];
			[mParameterUpdates release]; mParameterUpdates = nil;
		}
		@catch( NSException *theException ) {
			//[theException printStackTrace];
			if (!mFinishFlag) {
				NSLog(@"Exception during PSServer.m updateParameter:withObject:");
				NSLog(@"%@",[[mParameterUpdates allKeys] description]);
			}
			// clear the parameters that failed to update
			[mParameterUpdates release]; mParameterUpdates = nil;
			// assume controller has gone away
			[self setController:nil];
			returnValue = NO;
		}
	}
	return returnValue;
}

// ---------------------------------------------------------------------------
//	¥ reportError:code:
// ---------------------------------------------------------------------------
- (void)reportError:(NSString *)text withCode:(int)code
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
//		[mController receiveDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
//			PSReportErrorNotification, PSAction,
//            text, @"text", [NSNumber numberWithInt:code], @"code", nil]];			
	[self updateParameterD:@"text" withObject:text];
	[self updateParameterD:@"code" withObject:[NSNumber numberWithInt:code]];
	[self updateParameter:PSAction withObject:PSReportErrorNotification];
	[pool release];
}

// ---------------------------------------------------------------------------
//	¥ didUserAbort
// ---------------------------------------------------------------------------
// Send two-way message to check if user aborted.
// Notice we might get an exception if the connection is no longer valid.
- (BOOL)didUserAbort
{
	BOOL returnValue = NO;
	NS_DURING
		returnValue = [mController didUserAbort];
	NS_HANDLER
		if (![mConnection isValid]) returnValue = YES;
	NS_ENDHANDLER
	return returnValue;
}

// ---------------------------------------------------------------------------
//	¥ finish
// ---------------------------------------------------------------------------
// server has finished normally, clean up
- (void)finish {
    if (!mFinishFlag) {	// don't allow multiples
		mFinishFlag = YES;
		[self updateParameter:PSAction withObject:PSServerFinishedNotification];
		// cleanup after last message is sent
        [self cleanUp];
		// tell RunLoop to stop after next event
		mKeepRunning = NO;
    }
}

// ---------------------------------------------------------------------------
//	¥ cleanUp
// ---------------------------------------------------------------------------
- (void)cleanUp {
    // override to clean-up when server is killed
    if (!mCleanUpFlag) {	// don't allow multiples
		mCleanUpFlag = YES;
		[self setController:nil];
	}
}

@end

