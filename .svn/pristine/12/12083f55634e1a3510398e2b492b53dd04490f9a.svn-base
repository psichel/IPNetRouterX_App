//
//  ServiceEntry.h
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

@interface ServiceEntry : PSStateEntry {
}

// accessors
// could use key value coding, but this convenient and allows us to intervene
- (NSNumber *)enabled;
- (void)setEnabled:(NSNumber *)value;

- (NSString *)title;	// title identifing this device entry
- (void)setTitle:(NSString *)value;

- (NSString *)type;
- (void)setType:(NSString *)value;


- (NSString *)description;
@end

#define SE_enabled		@"enabled"
#define SE_title		@"title"
#define SE_type			@"type"
