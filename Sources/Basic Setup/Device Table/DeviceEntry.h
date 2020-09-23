//
//  DeviceEntry.h
//  IPNetRouterX
//
//  Created by Peter Sichel on 10/14/05.
//  Copyright 2005 Sustainable Softworks. All rights reserved.
//
// represent a Filter Style entry
// type
// continueWith

#import <Foundation/Foundation.h>
#import "PSStateEntry.h"

@interface DeviceEntry : PSStateEntry {
}

// accessors
// could use key value coding, but this convenient and allows us to intervene
- (NSNumber *)enabled;
- (void)setEnabled:(NSNumber *)value;

- (NSString *)title;	// title identifing this device entry
- (void)setTitle:(NSString *)value;

- (NSString *)type;		// either DE_typeNetworkPort or DE_typeAttachedDevice
- (void)setType:(NSString *)value;

- (NSNumber *)direction;
- (void)setDirection:(NSNumber *)value;

- (NSString *)portName;
- (void)setPortName:(NSString *)value;

- (NSString *)hwAddress;
- (void)setHwAddress:(NSString *)value;

- (NSString *)filterStyle;
- (void)setFilterStyle:(NSString *)value;


- (NSString *)description;
@end

#define DE_enabled		@"enabled"
#define DE_title		@"title"
#define DE_type			@"type"
#define DE_direction	@"direction"
#define DE_portName		@"portName"
#define DE_hwAddress	@"hwAddress"
#define DE_filterStyle	@"filterStyle"

#define DE_typeNetworkPort		@"networkPort"
#define DE_typeAttachedDevice	@"attachedDevice"
