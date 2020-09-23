//
//  DHCPLogger.m
//  IPNetRouterX
//
//  Created by Peter Sichel on Thu Nov 13 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
//	Encapsulate recording DHCP events (text messages)
//	Notify clients as new messages are added and recycle buffer as needed
//	(preferably by sending email and/or flushing to disk).

#import "DHCPLogger.h"
#import "SentryModel.h"
#import "SentryState.h"
#import "PSServiceDictionary.h"
#import "IPTypes.h"
#import "NSDate_Extensions.h"
#import "SendEmailController.h"
#import "SendEmailServer.h"

#define kLogBufferSize 65536

// Globals
//NSString *DHCPLoggerNotification = @"DHCPLoggerNotification";


@implementation DHCPLogger
+ (DHCPLogger *)sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[DHCPLogger alloc] init];
	}
	return sharedTask;
}

// ---------------------------------------------------------------------------------
//	¥ init
// ---------------------------------------------------------------------------------
- (id)init
{
    if (self = [super init]) {
        // initialize our instance variables
		mText = [[NSMutableString stringWithCapacity:kLogBufferSize] retain];
		[mText setString:@""];
		logTextLastSaved = nil;
		sentryAction = [SentryModel sharedInstance];   // OK
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	¥ dealloc
// ---------------------------------------------------------------------------------
- (void)dealloc {
	[self logTextSaveForDate:nil];
	[mText release];	mText = nil;
	[super dealloc];
}

// ---------------------------------------------------------------------------------
//	¥ addObserver
// ---------------------------------------------------------------------------------
- (void)addObserver:(id)target withSelector:(SEL)method {
    [[NSNotificationCenter defaultCenter] addObserver:target 
    selector:method 
    name:DHCPLoggerNotification 
    object:self];
}

// ---------------------------------------------------------------------------------
//	¥ removeObserver
// ---------------------------------------------------------------------------------
- (void)removeObserver:(id)target {
    [[NSNotificationCenter defaultCenter] removeObserver:target
        name:DHCPLoggerNotification
        object:self];
}

// ---------------------------------------------------------------------------------
//	¥ appendMessage:
// ---------------------------------------------------------------------------------
- (void)appendMessage:(NSString *)message
{
	NSDictionary* dictionary;
	NSCalendarDate* now;
	do {
		// if date has changed, save previous
		now = [NSCalendarDate date];
		if ([logTextLastSaved dayOfYear] != [now dayOfYear]) [self logTextSaveForDate:logTextLastSaved];
		// recycle log as needed
		if (([mText length] + [message length]) > kLogBufferSize) {
			// write to disk and or send as Email
			[self logTextSaveForDate:now];
		}
		// append text to log data
		if (!message) break;
		[mText appendString:message];
		// notify any listeners with new text
		dictionary = [NSDictionary dictionaryWithObject:message forKey:DHCPLoggerNotification];
		[[NSNotificationCenter defaultCenter]
			postNotificationName:DHCPLoggerNotification
			object:self
			userInfo:dictionary];
	}  while (false);
}

// ---------------------------------------------------------------------------------
//	¥ logTextSave
// ---------------------------------------------------------------------------------
// write to disk and or send as Email if enabled
- (void)logTextSaveForDate:(NSCalendarDate *)inDate
{
	if ([mText length]) {
		[self writeToFile:mText forDate:inDate];
		if ([[[sentryAction sentryState] emailDHCPLog] intValue]) {
			[[SentryLogger sharedInstance] sendEmail:mText withSubject:@"--- IPNetRouter DHCP Log ---"];
		}
		// clear log
		[mText setString:@""];
	}
	// update for next time
	[logTextLastSaved release];
	logTextLastSaved = [[NSCalendarDate date] retain];
}


// ---------------------------------------------------------------------------------
//	¥ writeToFile
// ---------------------------------------------------------------------------------
// write current log text to file if enabled
- (void)writeToFile:(NSString *)inText forDate:(NSCalendarDate *)inDate
{
	NSString* filePath;
	NSString* dirPath;
	NSString* dateString;
	BOOL isDir;
	do {
		if ([[[sentryAction sentryState] saveToCheckBox] intValue]) {
			NSFileManager* fm = [NSFileManager defaultManager];
			filePath = kDefaultLogPath;
			// check for directory
			if ([fm fileExistsAtPath:filePath isDirectory:&isDir] && !isDir)
				dirPath = [filePath stringByDeletingLastPathComponent];
			else dirPath = filePath;
			// determine filepath
			if (!inDate) inDate = [NSCalendarDate date];
			dateString = [inDate descriptionWithCalendarFormat:@"dhcp log %Y-%m-%d.txt"];
			filePath = [dirPath stringByAppendingPathComponent:dateString];			
			// does file already exist?
			if (![fm fileExistsAtPath:filePath]) {
				// does directory exist?
				if (![fm fileExistsAtPath:dirPath]) {
					// no, try to create directory
					[fm createDirectoryAtPath:dirPath attributes:nil];
				}
				// have directory, try to create file
				if (![fm createFileAtPath:filePath contents:[[self string] dataUsingEncoding:NSUTF8StringEncoding] attributes:nil])
					NSLog(@"DHCPLogger: unable to create file at path: %@",filePath);
					break;
			}
			else {
				// yes, append to existing contents
				NSFileHandle* fh = [NSFileHandle fileHandleForWritingAtPath:filePath];
				if (fh == nil) {
					NSLog(@"DHCPLogger: unable to access file at path: %@",filePath);
					break;
				}
				[fh seekToEndOfFile];
				[fh writeData:[inText dataUsingEncoding:NSUTF8StringEncoding]];
			}
		}
	} while (false);
}

- (NSString *)string
{
	return mText;
}

@end
