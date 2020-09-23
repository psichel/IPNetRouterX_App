//
//  BandwidthAccounting.m
//  IPNetSentryX
//
//  Created by Peter Sichel on Aug 7 2003.
//  Copyright (c) 2002 Sustainable Softworks, Inc. All rights reserved.
//
//	Encapsulate recording firewall events (text messages)
//	Notify clients as new messages are added and recycle buffer as needed
//	(preferably by sending email and/or flushing to disk).

#import "BandwidthAccounting.h"
#import "PreferencesController.h"
#import "SentryModel.h"
#import "SentryState.h"
#import "FilterTable.h"
#import "SentryLogger.h"


// Globals
NSString *BandwidthAccountingNotification = @"BandwidthAccountingNotification";


@implementation BandwidthAccounting
+ (BandwidthAccounting *)sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[BandwidthAccounting alloc] init];
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
		accountingTimer = nil;
		accountingLastSaved = nil;
		accountingDictionary = [[NSMutableDictionary alloc] init];
		if (!accountingDictionary) return nil;
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	¥ dealloc
// ---------------------------------------------------------------------------------
- (void)dealloc {
	// cancel accounting timer
	[self accountingStop];
	[accountingLastSaved release];	accountingLastSaved = nil;
    // release dictionaries we allocated
	[accountingDictionary release]; accountingDictionary = nil;
	[super dealloc];
}


// ---------------------------------------------------------------------------
//	¥ accountingStart:
// ---------------------------------------------------------------------------
// Capture bandwidth accounting information
// Normally repeats every hour
- (void)accountingStart
{
	NSTimeInterval seconds;
	// kick off bandwidth accounting timer if needed
	if (!accountingTimer) {
		// calculate accounting interval from string (menu title) "xx minutes"
		seconds = [[[[SentryModel sharedInstance] sentryState] accountingInterval] intValue] * 60;
		accountingTimer = [NSTimer
			scheduledTimerWithTimeInterval:seconds
			target:self
			selector:@selector(accountingTimer:)
			userInfo:nil
			repeats:YES];
		[self accountingTimer:nil];
	}
}


// ---------------------------------------------------------------------------
//	¥ accountingStop:
// ---------------------------------------------------------------------------
// Capture bandwidth accounting information
// Normally repeats every hour
- (void)accountingStop
{
	// cancel accounting timer
	[accountingTimer invalidate];	accountingTimer= nil;
}


// ---------------------------------------------------------------------------
//	¥ accountingTimer:
// ---------------------------------------------------------------------------
// Capture bandwidth accounting information
// Normally repeats every accounting interval (default 1 hour)
- (void)accountingTimer:(id)timer
{
	NSMutableDictionary* dataCount;
	FilterTable* filterTable;
	FilterEntry* entry;
	NSString* key;
	NSNumber* num;
	NSCalendarDate* now;
	int i, howMany;
	
	if ([[[SentryModel sharedInstance] sentryState] bandwidthAccounting]) do {
		// if date has changed
		now = [NSCalendarDate date];
		if ([accountingLastSaved dayOfYear] != [now dayOfYear])
			[self accountingSaveForDate:accountingLastSaved];		
		// get latest accounting data
		dataCount = [NSMutableDictionary dictionary];
		if (!dataCount) break;
		filterTable = [[[SentryModel sharedInstance] sentryState] filterTable];
		// for each filewall rule
		howMany = [filterTable nodeCount];
		for (i=1; i<=howMany; i++) {
			entry = [filterTable nodeForIndex:i];
			if (!entry) break;
			// if it has a _name?
			key = [entry nodeName];
			if ([key hasPrefix:@"_"]) {
				num = [entry byteCount];
				if (!num) num = [NSNumber numberWithInt:0];
				// save corresponding byte count under that name
				[dataCount setObject:num forKey:key];
			}
		}
		if ([dataCount count]) {	// any accounting data?
			// save count data under current NSCalendarDate
			[accountingDictionary setObject:dataCount forKey:[now description]];
		}
		// if set to write each time
		if ([[[SentryModel sharedInstance] sentryState] writeInterval]) [self accountingSaveForDate:now];
	} while (false);
}


// ---------------------------------------------------------------------------------
//	¥ accountingSave
// ---------------------------------------------------------------------------------
// write current log text to file if enabled
- (void)accountingSaveForDate:(NSCalendarDate *)inDate
{
	if ([accountingDictionary count]) {
		NSString* text;
		text = [accountingDictionary description];
		// write out accounting info
		if ([[[[SentryModel sharedInstance] sentryState] emailBandwidthLog] intValue]) {
			#ifdef IPNetRouter
			[[SentryLogger sharedInstance] sendEmail:text withSubject:@"--- IPNetRouter Bandwidth Log ---"];
			#else
			[[SentryLogger sharedInstance] sendEmail:text withSubject:@"--- IPNetSentry Bandwidth Log ---"];
			#endif
		}
		[self writeToFile:[text dataUsingEncoding:NSUTF8StringEncoding] forDate:inDate];
		[accountingDictionary removeAllObjects];
	}
	// update for next time
	[self setAccountingLastSaved:[NSCalendarDate date]];
}


// ---------------------------------------------------------------------------------
//	¥ setAccountingLastSaved
// ---------------------------------------------------------------------------------
- (NSCalendarDate *)accountingLastSaved { return accountingLastSaved; }
- (void)setAccountingLastSaved:(NSCalendarDate *)value {
	[value retain];
	[accountingLastSaved release];
	accountingLastSaved = value;
}


// ---------------------------------------------------------------------------------
//	¥ writeToFile
// ---------------------------------------------------------------------------------
// write current log text to file if enabled
- (void)writeToFile:(NSData *)inData forDate:(NSCalendarDate *)inDate
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
			dateString = [inDate descriptionWithCalendarFormat:@"bandwidth log %Y-%m-%d.plist"];
			filePath = [dirPath stringByAppendingPathComponent:dateString];
			// does file already exist?
			if (![fm fileExistsAtPath:filePath]) {
				// does directory exist?
				if (![fm fileExistsAtPath:dirPath]) {
					// no, try to create directory
					[fm createDirectoryAtPath:dirPath attributes:nil];
				}
				// have directory, try to create file
				if (![fm createFileAtPath:filePath contents:inData attributes:nil])
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
				// remove trailing }
				{
					long long offset;
					offset = [fh offsetInFile];
					offset -= 1;
					[fh seekToFileOffset:offset];
				}
				// remove leading {
				{
					NSData* data;
					NSRange range;
					range.location = 1;
					range.length = [inData length] - 1;
					data = [inData subdataWithRange:range];
					[fh writeData:data];
				}
				//[fh writeData:inData];
			}
		}
	} while (false);
}

@end
