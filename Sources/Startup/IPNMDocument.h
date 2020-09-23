//
//  IPNMDocument.h
//  IPNetMonitorX
//
//  Created by Peter Sichel on 11/2/06.
//  Copyright 2006 Sustainable Softworks. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface IPNMDocument : NSDocument {
	NSString* dataString;
}
- (NSString *)dataString;
- (void) setDataString:(NSString *)value;

@end
