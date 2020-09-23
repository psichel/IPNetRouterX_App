//
//  ConnectionLog.m
//  IPNetSentryX
//
//  Created by Peter Sichel on Wed Aug 20 2003.
//  Copyright (c) 2002 Sustainable Softworks, Inc. All rights reserved.
//
//	Encapsulate saving connection log info
//
#import "ConnectionLog.h"
#import "PreferencesController.h"
#import "SentryModel.h"
#import "SentryState.h"
#import "FilterTable.h"
#import "SentryLogger.h"


// Globals
NSString *ConnectionLogNotification = @"ConnectionLogNotification";


@implementation ConnectionLog
+ (ConnectionLog *)sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[ConnectionLog alloc] init];
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
		connectionLogTimer = nil;
		connectionLogLastSaved = nil;
		connectionLogArray = [[NSMutableArray alloc] init];
		if (!connectionLogArray) return nil;
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	¥ dealloc
// ---------------------------------------------------------------------------------
- (void)dealloc {
	// cancel connectionLog timer
	[self connectionLogStop];
	[connectionLogLastSaved release];	connectionLogLastSaved = nil;
    // release array we allocated
	[connectionLogArray release]; connectionLogArray = nil;
	[super dealloc];
}

// ---------------------------------------------------------------------------
//	¥ connectionLogStart
// ---------------------------------------------------------------------------
// Capture connectionLog information
// Normally repeats every hour
- (void)connectionLogStart
{
	NSTimeInterval seconds;
	// kick off connectionLog timer if needed
	if (!connectionLogTimer) {
		// calculate connectionLog interval (just use 10 minutes for now)
		seconds = 600;
		connectionLogTimer = [NSTimer
			scheduledTimerWithTimeInterval:seconds
			target:self
			selector:@selector(connectionLogTimer:)
			userInfo:nil
			repeats:YES];
	}
}


// ---------------------------------------------------------------------------
//	¥ connectionLogStop
// ---------------------------------------------------------------------------
// Capture connectionLog information
// Normally repeats every hour
- (void)connectionLogStop
{
	// cancel connectionLog timer
	[connectionLogTimer invalidate];	connectionLogTimer= nil;
}


// ---------------------------------------------------------------------------
//	¥ connectionLogTimer:
// ---------------------------------------------------------------------------
// Capture connectionLog information
// Normally repeats every connectionLog interval (default 10 minutes)
- (void)connectionLogTimer:(id)timer
{
	if ([[[SentryModel sharedInstance] sentryState] connectionLogging]) {
		if ([connectionLogLastSaved timeIntervalSinceNow] < -600) [self connectionLogSaveForDate:nil];
	}
}


// ---------------------------------------------------------------------------------
//	¥ connectionLogAppend
// ---------------------------------------------------------------------------------
- (void)connectionLogAppend:(NSDictionary *)connectionEntry
{
	// if date has changed, save previous
	if ([connectionLogLastSaved dayOfYear] != [[NSCalendarDate date] dayOfYear])
		[self connectionLogSaveForDate:connectionLogLastSaved];
	// add entry
	[connectionLogArray addObject:connectionEntry];
	// recycle log array as needed
	if ([connectionLogArray count] > 100) [self connectionLogSaveForDate:nil];
}


// ---------------------------------------------------------------------------------
//	¥ connectionLogSave
// ---------------------------------------------------------------------------------
// write current log text to file if enabled
- (void)connectionLogSaveForDate:(NSCalendarDate *)inDate
{
	if ([connectionLogArray count]) {
		NSString* text;
		text = [connectionLogArray description];
		// write out connectionLog info
		if ([[[[SentryModel sharedInstance] sentryState] emailConnectionLog] intValue]) {
			#ifdef IPNetRouter
			[[SentryLogger sharedInstance] sendEmail:text withSubject:@"--- IPNetRouter Connection Log ---"];
			#else
			[[SentryLogger sharedInstance] sendEmail:text withSubject:@"--- IPNetSentry Connection Log ---"];
			#endif
		}
		[self writeToFile:text forDate:inDate];
		[connectionLogArray removeAllObjects];
	}
	// update for next time
	[connectionLogLastSaved release];
	connectionLogLastSaved = [[NSCalendarDate date] retain];
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
		if ([[[[SentryModel sharedInstance] sentryState] saveToCheckBox] intValue]) {
			NSFileManager* fm = [NSFileManager defaultManager];
			filePath = kDefaultLogPath;
			// check for directory
			if ([fm fileExistsAtPath:filePath isDirectory:&isDir] && !isDir)
				dirPath = [filePath stringByDeletingLastPathComponent];
			else dirPath = filePath;
			// determine filepath
			if (!inDate) inDate = [NSCalendarDate date];
			dateString = [inDate descriptionWithCalendarFormat:@"connection log %Y-%m-%d.plist"];
			filePath = [dirPath stringByAppendingPathComponent:dateString];
			// does file already exist?
			if (![fm fileExistsAtPath:filePath]) {
				// does directory exist?
				if (![fm fileExistsAtPath:dirPath]) {
					// no, try to create directory
					[fm createDirectoryAtPath:dirPath attributes:nil];
				}
				// have directory, try to create file
				if (![fm createFileAtPath:filePath contents:[inText dataUsingEncoding:NSUTF8StringEncoding] attributes:nil])
					NSLog(@"SentryLogger: unable to create file at path: %@",filePath);
					break;
			}
			else {
				// yes, append to existing contents
				NSFileHandle* fh = [NSFileHandle fileHandleForWritingAtPath:filePath];
				if (fh == nil) {
					NSLog(@"SentryLogger: unable to access file at path: %@",filePath);
					break;
				}
				[fh seekToEndOfFile];
				// remove trailing )
				{
					long long offset;
					offset = [fh offsetInFile];
					offset -= 1;
					[fh seekToFileOffset:offset];
				}
				// change leading ( to ,
				{
					NSMutableString* text;
					NSRange range;
					text = [NSMutableString stringWithCapacity:[inText length]];
					[text setString:inText];
					range = [text rangeOfString:@"("];
					[text replaceCharactersInRange:range withString:@","];
					[fh writeData:[text dataUsingEncoding:NSUTF8StringEncoding]];
				}
				//[fh writeData:[inText dataUsingEncoding:NSUTF8StringEncoding]];
			}
		}
	} while (false);
}

@end
