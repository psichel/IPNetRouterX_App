//
//  SendEmailServer.h
//  IPNetRouterX
//
//  Created by psichel on Thu Dec 18 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//
//  Encapsulates a Distributed Objects connection between a
//  SendEmail client and server thread.  We use DO to isolate networking
//  in a thread safe container.

#import <Foundation/Foundation.h>
#import "PSServer.h"
#import "PSServerInterface.h"
@class SendEmailAction;
@class PSURL;


@interface SendEmailServer : PSServer
{
}
- (int)sendEmail:(PSURL *)url withObject:(id)anObject;
- (int)serverTerminate:(PSURL *)url withObject:(id)anObject;

@end

#define kSendEmail			@"sendemail"
#define kServerTerminate	@"terminate"

