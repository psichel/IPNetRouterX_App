//
//  FilterStyleEntry.h
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

@interface FilterStyleEntry : PSStateEntry {
}

// accessors
- (NSString *)title;	// title identifing this device entry
- (void)setTitle:(NSString *)value;

- (NSString *)type;
- (void)setType:(NSString *)value;
// could use key value coding, but this convenient and allows us to intervene

- (NSString *)description;
@end

#define SE_title		@"title"
#define SE_type			@"type"
#define SE_continueWith	@"continueWith"
