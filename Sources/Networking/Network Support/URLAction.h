//
//  URLAction.h
//  IPNetMonitorX
//
//  Created by psichel on Mon Sep 13 2004.
//  Copyright (c) 2004 Sustainable Softworks. All rights reserved.
//
//  Encapsulates performing a ping test in a separate thread.
//  We use a Distributed Objects (DO) server design to synchronize
//  with the main AppKit UI thread.
//

#import <Foundation/Foundation.h>
#import "PSServer.h"
@class IPHost;

@interface URLAction : PSServer
{
	// ping
	IPHost* mTarget;
	int mSequenceNumber;
	BOOL mPingInProgress;
}

- (void)messageNotification:(NSNotification *)aNotification;
@end

#define kURLData @"urlData"