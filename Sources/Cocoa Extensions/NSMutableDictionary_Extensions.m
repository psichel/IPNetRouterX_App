//
//  NSMutableDictionary_Extensions.h
//
//  Created by psichel on Tues Dec 23 2003.
//  Copyright (c) 2001 Sustainable Softworks, Inc. All rights reserved.
//
//	Add setValue:forKey: method

#import "NSMutableDictionary_Extensions.h"

@implementation NSMutableDictionary (PSExtensions)
- (void)setValue:(id)value forKey:(NSString *)key
{
	if (value) [self setObject:value forKey:key];
	else [self removeObjectForKey:key];
}
@end
