//
//  LookupServer.h
//  IPNetMonitorX
//
//  Created by psichel on Wed Oct 17 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Encapsulates performing a DNS lookup in a separate thread.
//  We use a Distributed Objects (DO) server design to synchronize
//  with the main AppKit UI thread.
//

#import <Foundation/Foundation.h>
//#import <AppKit/AppKit.h>
#import "PSServer.h"
#import "PSServerInterface.h"
@class PSURL;

@interface LookupServer : PSServer
{
    PSURL*		mURL;
}

- (void)lookup;
@end

#define kURL_lookup			@"lookup"

#define kStatusInfo			@"statusInfo"
#define kLookupField		@"lookupField"
#define kResultField		@"resultField"
#define kNoAddressFound		@"noAddressFound"
#define kLookupComplete		@"lookupComplete"
