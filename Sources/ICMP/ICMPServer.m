//
//  ICMPServer.m
//  IPNetMonitorX
//
//  Created by psichel on Thu Nov 28 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Encapsulates an ICMP receive thread that waits for ICMP
//  traffic and packages any ICMP datagrams with a timestamp.
//
#import "ICMPServer.h"
#import "IPHost.h"
#import "IPICMPSocket.h"
#import "IPNetMessage.h"
#import "PSURL.h"
#import "unp.h"


@implementation ICMPServer

// -- Thread Server Interface --
- (oneway void)startService:(NSString *)inURL fromController:(id)controller withObject:(id)object
// see comments in PSServerInterface.h
{
    NSAutoreleasePool* pool1;
    NSAutoreleasePool* pool2;
    IPICMPSocket*	icmpSocket;   
    NSMutableData*	receiveBuf;
    NSMutableData*	controlBuf;
    IPHost* host=nil;
    NSDate* receiveTime=nil;
    IPNetMessage* message=nil;
    PSURL* url=nil;
	NSTimeInterval lastAbortCheck;
//	NSTimeInterval delta;
	int lastAbortCount = 0;
    
    // The following line is an interesting optimisation.  We tell our proxy
    // to the controller object about the methods that we're going to
    // send to the proxy.    
    [controller setProtocolForProxy:@protocol(ControllerFromThread)];
    // init method vars
	pool1 = [[NSAutoreleasePool alloc] init];
	[self setController:controller];
    receiveBuf = nil;
    controlBuf = nil;
    icmpSocket = nil;
    do {
		if (mFinishFlag) {
			[self reportError:NSLocalizedString(@"Server is terminating",@"Server is terminating") withCode:0];
			break;
		}
        // extract ICMP parameters
        // icmp://socket
        url = [[[PSURL alloc] init] autorelease];
        [url setStringValue:inURL];
		if (![[url scheme] isEqualTo:@"icmp"]) {
            [self updateParameter:@"statusInfo" withObject:NSLocalizedString(@"Target not recognized",@"Target not recognized")];
            break;
        }
		// socket
		int socket = [[url host] intValue];
		icmpSocket = [[IPICMPSocket alloc] initWithSocket:socket];
		[icmpSocket autorelease];
		[icmpSocket setSO_TIMESTAMP:1];
        // setup receive buffer
        if (receiveBuf == nil) {
            receiveBuf = [NSMutableData dataWithCapacity:kICMPBufferSize];
            [[receiveBuf retain] autorelease];
        }
        if (receiveBuf == nil) break;
        // setup control buffer
        if (controlBuf == nil) {
            controlBuf = [NSMutableData dataWithCapacity:kControlBufferSize];
            [[controlBuf retain] autorelease];
        }
        // setup host object to receive from address
        host = [[[IPHost alloc] init] autorelease];
		// give caller a handle to wake us up
		[self updateParameter:PSAbortFD withObject:[NSString stringWithFormat:@"%d",[icmpSocket abortFD]]];
		{   // initialize last abort check time
			timeval_t tv;
			gettimeofday(&tv, NULL);
			lastAbortCheck = tv.tv_sec + (double)tv.tv_usec*0.000001;
		}
        // infinite loop to receive UDP data
        while (true) {
            BOOL abortFlag = NO;
			int result = 0;
            pool2 = [[NSAutoreleasePool alloc] init];
			@try {
				// re-init receive buffer size
				[receiveBuf setLength:kICMPBufferSize];
				[controlBuf setLength:kControlBufferSize];
				[host setHAddress:0];
				// receive any data
				result = [icmpSocket receiveFrom:host
					data:receiveBuf control:controlBuf withTimeOut:(NSTimeInterval)2.0];
				if (result > 0) {
					// some data came in from the network
					// look for kernel timestamp
					{
						cmsghdr_t* cmsg;
						time_value_t* tval;
						NSTimeInterval value;
						cmsg = [controlBuf mutableBytes];
						if ((cmsg->cmsg_len == sizeof(cmsghdr_t) + sizeof(time_value_t)) &&
							(cmsg->cmsg_level == SOL_SOCKET) &&
							(cmsg->cmsg_type == SCM_TIMESTAMP)) {
							tval = (time_value_t *)CMSG_DATA(cmsg);
							//value = tval->tv_sec + (double)tval->tv_usec*0.000001;
							value = tval->seconds + (double)tval->microseconds*0.000001;
							receiveTime = [[NSDate dateWithTimeIntervalSince1970:value] retain];
						}
					}
					// build an IPNetMessage                
					message = [[IPNetMessage alloc] init];
					[message setTimeStamp:receiveTime];
					[message setFromHost:host];
					[message setData:receiveBuf];
					[message setControl:controlBuf];
					[message setSocket:[icmpSocket socket]];
					// pass message to controller                
					[self updateParameter:ICMPMessageNotification withObject:message];
					lastAbortCount++;
					// and release
					[message release];
					[receiveTime release];	receiveTime = nil;
				}
				else if (result < 0) {
					// receive error
					// normal abort could generate a "bad socket error" (EBADF) when fd is closed
					int errno_save = errno;
					if (errno_save == EBADF) {	// socket was closed
						abortFlag = YES;
					}
					else {
						[self reportError:NSLocalizedString(@"Receive error",@"Receive error") withCode:result];
						[self reportError:[NSString stringWithFormat:@"%s",strerror(errno_save)] withCode:errno_save];
					}
				}
				// data received (result>0), receive error (result<0), or timeout (result=0)
				// do not check if user aborted since controller should never abort
#if 0
				// since didUserAbort is expensive, do not repeat for every valid message
				if (!abortFlag) {
				   // calculate delta since last didUserAbort
					NSTimeInterval now;
					timeval_t tv;
					gettimeofday(&tv, NULL);
					now = tv.tv_sec + (double)tv.tv_usec*0.000001;
					delta = now - lastAbortCheck;
					if ((delta > 1.9) || (lastAbortCount > 9)) {
						if ([self didUserAbort]) abortFlag = YES;
						// remember last abort check time
						lastAbortCheck = now;
						lastAbortCount = 0;
					}
				}
#endif
			}
			@catch( NSException *theException ) {
				//[theException printStackTrace];
				abortFlag = YES;	// unexpected exception exit loop normally
				NSLog(@"Exception during ICMPServer.m -startService");
			}

            [pool2 release];
			if (abortFlag) break;
        }	// receive loop
    } while (false);
    [pool1 release];	// notice this will release pool2 if it's still on the stack
//    [icmpSocket release]; icmpSocket = nil;
//    [receiveBuf release]; receiveBuf = nil;
//    [controlBuf release]; controlBuf = nil;
    [self finish];
}
@end
