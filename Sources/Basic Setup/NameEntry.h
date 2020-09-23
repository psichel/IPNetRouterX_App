//
//  NameEntry.h
//  IPNetRouterX
//
//  Created by Peter Sichel on Thu Jun 3 2004.
//  Copyright (c) 2004 Sustainable Softworks, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PSStateEntry.h"

@interface NameEntry : PSStateEntry {
}

// accessors
- (NSString *)title;
- (void)setTitle:(NSString *)value;

- (NSString *)identifier;
- (void)setIdentifier:(NSString *)value;
@end

#define NE_title @"title"
#define NE_identifier @"identifier"
