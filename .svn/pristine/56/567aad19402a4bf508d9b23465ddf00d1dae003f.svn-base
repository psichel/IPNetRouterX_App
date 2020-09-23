//
//  SentryDocument.h
//  IPNetSentryX
//
//  Created by Peter Sichel on Wed Jul 24 2002.
//  Copyright (c) 2001 Sustainable Softworks, Inc. All rights reserved.
//
//  Encapsulate IPNetSentryX/IPNetRouterX document as part of MVC design.
//
//  SentryDocument displays the current model and interprets user input to change model state.
//  SentryState maintains the model state and notifies observers when it changes.
//  SentryModel observes state changes and performs the corresponding model action.
//
//  SentryDocument plays two basic roles:
//  (1) receive state change notifications from SentryState and update
//  	the displayed state accordingly;
//  (2) interpret user input and call SentryState to modify the
//		model state accordingly.

#import <Cocoa/Cocoa.h>
@class FilterTable;
@class FilterEntry;
@class PSPropertyValue;
@class IPNetMessage;
@class SentryState;
@class SentryLogger;

@interface SentryDocument : NSDocument
{
	SentryState*	sentryState;
}

- (SentryDocument *)init;
- (void)loadActive;
@end

