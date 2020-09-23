//
//  NSMutableDictionary_Extensions.h
//
//  Created by psichel on Tue Dec 23 2003.
//  Copyright (c) 2001 Sustainable Softworks, Inc. All rights reserved.
//
//	Add setValue:forKey: method

#import <Foundation/Foundation.h>

@interface NSMutableDictionary (PSExtensions)
- (void)setValue:(id)value forKey:(NSString *)key;
@end

