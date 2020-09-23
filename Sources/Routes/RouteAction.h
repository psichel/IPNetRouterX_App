//
//  RouteAction.h
//  IPNetRouterX
//
//  Created by psichel on Wed Mar 05 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.
//
//  Encapsulates reading TCP Connection List in a separate thread.
//  We use a Distributed Objects (DO) server design to synchronize
//  with the main AppKit UI thread.
//

#import <Foundation/Foundation.h>
//#import <AppKit/AppKit.h>
#import "PSServer.h"
#import "PSServerInterface.h"
@class RouteServer;
@class PSURL;

@interface RouteAction : NSObject
{
    id				delegate;
	NSMutableData*	mBuffer;	// buffer to hold sysctl data
    int				mBufferSize;
	int				mRoutingSocket;
}
+ (RouteAction *)sharedInstance;
- (id)delegate;
- (void)setDelegate:(id)value;

- (NSMutableArray *)routeList:(id)anObject;
- (int)routeAdd:(id)anObject;
- (int)routeDelete:(id)anObject;
- (int)routeChange:(id)anObject;

- (NSMutableArray *)arpList:(id)anObject;
- (int)arpAdd:(id)anObject;
- (int)arpDelete:(id)anObject;
@end

#define kRouteList  @"routeList"
#define kRouteAdd   @"routeAdd"
#define kRouteDelete @"routeDelete"
#define kRouteChange @"routeChange"
#define kTerminate  @"terminate"

#define kArpList  @"arpList"
#define kArpAdd   @"arpAdd"
#define kArpDelete @"arpDelete"
