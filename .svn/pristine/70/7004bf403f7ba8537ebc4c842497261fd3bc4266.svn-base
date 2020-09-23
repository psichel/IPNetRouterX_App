#import "PortRangeFormatter.h"
#import "IPValue.h"

@implementation PortRangeFormatter
+ (PortRangeFormatter *) sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[PortRangeFormatter alloc] init];
	}
	return sharedTask;
}
// Return the hyphen separated port range if present
- (NSString *)stringForObjectValue:(id)inIPValue {
    NSMutableString *str = [[[NSMutableString alloc] initWithCapacity:32] autorelease];

    do {
        // test passed in object for correct class
        if (![inIPValue isKindOfClass:[IPValue class]]) break;
    
		// append port range if present
		if ([inIPValue startPort]) {
			[str appendFormat:@"%d", (SInt32)[inIPValue startPort]];
			if ([inIPValue endPort]) {
				[str appendFormat:@"-%d", (SInt32)[inIPValue endPort]];
			}
		}
    } while (false);
    return str;
}

// load IPValue from hyphen separated port range string
- (BOOL)getObjectValue:(id *)outIPValue forString:(NSString *)inString errorDescription:(NSString **)error {
    BOOL	retval = NO;
	int startPort = 0;
	int endPort = 0;
	NSScanner* theScanner;
	        
	if (inString) {
		theScanner = [NSScanner scannerWithString:inString];
		if ([theScanner scanInt:&startPort]) {
			if ([theScanner scanString:@"-" intoString:NULL]) {
				// found "-"
				if ([theScanner scanInt:&endPort]) {
					if ((endPort > 0) && (endPort < startPort)) {
						int temp;
						temp = startPort;
						startPort = endPort;
						endPort = temp;
					}
				}
			}
		}
	}
		// set result
	if (outIPValue) {
		IPValue* theObject;
		theObject = [[[IPValue alloc] init] autorelease];
		[theObject setStartPort:startPort];
		[theObject setEndPort:endPort];
		*outIPValue = theObject;
		retval = YES;
	}
    return retval;
}

- (NSAttributedString *)attributedStringForObjectValue:(id)anObject withDefaultAttributes:(NSDictionary *)attributes {
    NSAttributedString *theString;
    // create attributed string for object
    theString = [[NSAttributedString alloc] initWithString:[self stringForObjectValue:anObject] attributes:attributes];
    [theString autorelease];
    return theString;
}

@end
