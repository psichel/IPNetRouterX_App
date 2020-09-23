//
//  IPNMDocument.m
//  IPNetMonitorX
//
//  Created by Peter Sichel on 11/2/06.
//  Copyright 2006 Sustainable Softworks. All rights reserved.
//

#import "IPNMDocument.h"
//#import "PSGetURLScriptCommand.h"
#import "PSURL.h"
#import <syslog.h>
#import <stdarg.h>


@implementation IPNMDocument
// ---------------------------------------------------------------------------------
//	¥ init
// ---------------------------------------------------------------------------------
- init
{
    if (self = [super init]) {
		dataString = nil;
    }
    return self;
}
- (void)dealloc
{
	[self setDataString:nil];
    [super dealloc];
}

#if 0
- (NSString *)windowNibName {
    // Implement this to return a nib to load OR implement -makeWindowControllers to manually create your controllers.
    return @"IPNMDocument";
}
#endif

- (NSData *)dataRepresentationOfType:(NSString *)type {
    // Implement to provide a persistent data representation of your document OR remove this and implement the file-wrapper or file path based save methods.
    return nil;
}

- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)type {
    // Implement to load a persistent data representation of your document OR remove this and implement the file-wrapper or file path based load methods.
    return YES;
}

// ---------------------------------------------------------------------------------
//	¥ readFromFile
// ---------------------------------------------------------------------------------
- (BOOL)readFromFile:(NSString *)fileName ofType:(NSString *)docType
{
    BOOL returnValue = NO;
	PSURL* url;
	NSString* result = nil;
	NSWindowController* controller = nil;
	NSArray* list;
	NSString* line;
	int count, i;
	NSRange range;
	
	NSString* inputText = [NSString stringWithContentsOfFile:fileName encoding:NSUTF8StringEncoding error:nil];
	if (inputText) {
		returnValue = YES;
		list = [inputText componentsSeparatedByString:@"\n"];
		count = [list count];
		for (i=0; i<count; i++) {
			// examine line from file
			line = [list objectAtIndex:i];
			// look for <...>
			range = [line rangeOfString:@"<"];
			if (range.length) line = [line substringFromIndex:range.location];
			range = [line rangeOfString:@">"];
			if (range.length) line = [line substringToIndex:range.location+range.length];
			// initialize url object to examine components
			{
				url = [[PSURL alloc] init];
				[url setStringValue:line];
				// perform GetURL
//				result = [[PSGetURLScriptCommand sharedInstance] performURL:url windowController:&controller];
				[url release];
			}
			if (controller && (i==0)) {
				//[controller setDocument:self];	// associate document with window so it will be closed as needed
				[self addWindowController:controller];	// associate document with window so it will be closed as needed
				[self setFileName:fileName];
				[self setDataString:line];
			}
			if (result) {
				syslog(LOG_NOTICE, "%s", [result UTF8String]);
			}
		}
	}
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	¥ writeToFile
// ---------------------------------------------------------------------------------
- (BOOL)writeToFile:(NSString *)fileName ofType:(NSString *)type
{
	return [dataString writeToFile:fileName atomically:NO encoding:NSUTF8StringEncoding error:nil];
}

// ---------------------------------------------------------------------------------
//	¥ dataString
// ---------------------------------------------------------------------------------
- (NSString *)dataString { return dataString; }
- (void) setDataString:(NSString *)value {
	[value retain];
	[dataString release];
	dataString = value;
}

@end
