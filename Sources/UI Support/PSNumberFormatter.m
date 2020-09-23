#import "PSNumberFormatter.h"
#import "IPValue.h"

@implementation PSNumberFormatter
// Return the string representing a large quantity or bandwidth (K, M, G)
// anObject is expected to be an NSNumber
- (NSString *)stringForObjectValue:(id)anObject {
    NSString* returnValue;
    float value;
    
    value = [anObject floatValue];
    if (value > 4.294967e+09) returnValue = [NSString stringWithFormat:@"%.00fG", value/1.073742e+09];
    else if (value > 4194304) returnValue = [NSString stringWithFormat:@"%.0fM", value/1048576];
    else if (value > 4096) returnValue = [NSString stringWithFormat:@"%.0fK", value/1024];
    else returnValue = [NSString stringWithFormat:@"%.0f", value];
    return returnValue;
}

// return NSNumber for corresponding string with (K, M, or G)
- (BOOL)getObjectValue:(id *)outNumber forString:(NSString *)inString errorDescription:(NSString **)error {
    NSString* str;
    float value;

    if (error) *error = nil;
    if ([inString hasSuffix:@"K"]) {
        str = [inString substringToIndex:[inString length]-1];
        value = [str floatValue];
        value = value * 1024;
        *outNumber = [NSNumber numberWithFloat:value];
    }
    else if ([inString hasSuffix:@"M"]) {
        str = [inString substringToIndex:[inString length]-1];
        value = [str floatValue];
        value = value * 1048576;
        *outNumber = [NSNumber numberWithFloat:value];
    }
    else if ([inString hasSuffix:@"G"]) {
        str = [inString substringToIndex:[inString length]-1];
        value = [str floatValue];
        value = value * 1.073742e+09;
        *outNumber = [NSNumber numberWithFloat:value];
    }
    else {
        value = [inString floatValue];
        *outNumber = [NSNumber numberWithFloat:value];
    }

    //*error = NSLocalizedString(@"Couldn't convert to NSNumber object", @"Bad object pointer");
    return YES;
}

- (NSAttributedString *)attributedStringForObjectValue:(id)anObject withDefaultAttributes:(NSDictionary *)attributes {
    NSAttributedString *theString;
    // create attributed string for object
    theString = [[NSAttributedString alloc] initWithString:[self stringForObjectValue:anObject] attributes:attributes];
    [theString autorelease];
    return theString;
}

@end
