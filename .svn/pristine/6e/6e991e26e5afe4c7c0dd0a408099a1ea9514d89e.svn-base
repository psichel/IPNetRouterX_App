//
//  HardwareAddressFormatter.h
//  IPNetRouterX
//
//  Created by psichel on Thu Nov 6 2003.
//  Copyright (c) 2003 Sustainable Softworks. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HardwareAddress;

@interface HardwareAddressFormatter : NSFormatter
{
}
+ (HardwareAddressFormatter *)sharedInstance; // returns a shared instance of the class
- (NSString *)stringForObjectValue:(id)anObject;
- (BOOL)getObjectValue:(id *)anObject forString:(NSString *)string errorDescription:(NSString **)error;
- (NSAttributedString *)attributedStringForObjectValue:(id)anObject withDefaultAttributes:(NSDictionary *)attributes;
@end
