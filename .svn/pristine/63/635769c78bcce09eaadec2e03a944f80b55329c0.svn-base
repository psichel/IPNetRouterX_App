#import <Cocoa/Cocoa.h>

@class IPValue;

@interface IPValueFormatter : NSFormatter
{
}
+ (IPValueFormatter *)sharedInstance; // returns a shared instance of the class
- (NSString *)stringForObjectValue:(id)anObject;
- (BOOL)getObjectValue:(id *)anObject forString:(NSString *)string errorDescription:(NSString **)error;
- (NSAttributedString *)attributedStringForObjectValue:(id)anObject withDefaultAttributes:(NSDictionary *)attributes;
@end
