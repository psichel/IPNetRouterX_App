//
//  ListenServer.h
//  IPNetRouterX
//
//  Created by psichel on Thu Dec 18 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//
//  Encapsulates a Distributed Objects connection between a
//  Listen client and server thread.  We use DO to isolate networking
//  in a thread safe container.

#import <Foundation/Foundation.h>
#import "PSServer.h"
#import "PSServerInterface.h"
@class PSURL;


@interface ListenServer : PSServer
{
}

@end

