//
//  SendEmailController.h
//  IPNetRouterX
//
//  Created by psichel on Thu Dec 18 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//
//  Encapsulates a Distributed Objects connection between a
//  Send SendEmail client and server thread.  We use DO to isolate networking
//  in a thread safe container.

#import <Cocoa/Cocoa.h>
#import "PsClient.h"
#import "SendEmailServer.h"

@interface SendEmailController : PsClient
{
}
+ (SendEmailController *)sharedInstance;
    // returns a shared instance of the class
@end
