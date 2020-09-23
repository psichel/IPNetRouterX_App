//
//  AirPortConfigurationWindowC.m
//  IPNetRouterX
//
//  Created by Peter Sichel on Mon Dec 29 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.

#import <Cocoa/Cocoa.h>

@interface AirPortConfigurationWindowC : NSWindowController
{
    IBOutlet NSButton *restoreCB;
	IBOutlet NSPopUpButton *portType;
	IBOutlet NSPopUpButton *apMode;
    IBOutlet NSPopUpButton *channel;
    IBOutlet NSPopUpButton *encryptionType;
    IBOutlet NSTextField *networkName;
    IBOutlet NSSecureTextField *password;
    IBOutlet NSSecureTextField *confirm;
	IBOutlet NSTextField *statusInfo;
}
- (void)awakeFromNib;
- (IBAction)apply:(id)sender;
- (IBAction)myHelp:(id)sender;
@end

#define kAirPortConfigurationName			@"AirPortConfiguration"
#define kAirPortConfiguration_open			@"AirPortConfiguration_open"
