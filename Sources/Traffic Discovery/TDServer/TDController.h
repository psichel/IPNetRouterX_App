//
//  TDController.h
//  IPNetRouterX
//
//  Created by psichel on Wed Jan 24 2007.
//  Copyright (c) 2007 Sustainable Softworks. All rights reserved.
//
//  Encapsulates performing Traffic Discovery I/O in a separate thread
//  so we don't block while using NSPropertyListSerialization classes

#import <Cocoa/Cocoa.h>
#import "PsClient.h"
#import "TDServer.h"

@interface TDController : PsClient
{
}
+ (TDController *)sharedInstance;
    // returns a shared instance of the class
@end
