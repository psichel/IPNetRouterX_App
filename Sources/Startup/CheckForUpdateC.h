//
//  CheckForUpdateC.h
//  IPNetRouterX
//
//  Created by Peter Sichel on Fri May 20 2005.
//  Copyright (c) 2005 Sustainable Softworks, Inc. All rights reserved.
//
//  Check if newer version of software is available from sustworks website.

#import <Cocoa/Cocoa.h>
@class PsClient;

@interface CheckForUpdateC : NSWindowController
{
    IBOutlet NSTextField *statusInfo;
	// URL Action
	PsClient*		mURLClient;
}
- (IBAction)dismiss:(id)sender;
- (IBAction)download:(id)sender;
@end


#define kCheckForUpdateName	@"CheckForUpdate"