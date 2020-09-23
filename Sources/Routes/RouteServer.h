//
//  RouteServer.h
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
#import "RouteAction.h"

@interface RouteServer : PSServer
{
	RouteAction* routeAction;
}
@end

