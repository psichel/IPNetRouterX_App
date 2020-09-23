////  NSDate_Extensions.h////  Created by psichel on Tues Dec 23 2003.//  Copyright (c) 2001 Sustainable Softworks, Inc. All rights reserved.////	Work around synchronization bug in [NSDate date] versus UNIX gettimeofday()#import "NSDate_Extensions.h"#import <sys/time.h>@implementation NSDate (PSExtensions)+ (NSDate *)psDate{	struct timeval tv;	NSTimeInterval value;	gettimeofday(&tv, NULL);	value = tv.tv_sec + (double)tv.tv_usec*0.000001;	return [NSDate dateWithTimeIntervalSince1970:value];}+ (NSTimeInterval)psInterval{	struct timeval tv;	NSTimeInterval value;	gettimeofday(&tv, NULL);	value = tv.tv_sec + (double)tv.tv_usec*0.000001;	return value;}- (NSTimeInterval)psTimeIntervalSinceNow{	struct timeval tv;	NSTimeInterval value;	gettimeofday(&tv, NULL);	value = tv.tv_sec + (double)tv.tv_usec*0.000001;	return ([self timeIntervalSince1970] - value);}@end