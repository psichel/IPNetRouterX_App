//
//  SentryLogger.m
//  IPNetSentryX
//
//  Created by Peter Sichel on Sun Dec 29 2002.
//  Copyright (c) 2002 Sustainable Softworks, Inc. All rights reserved.
//
//	Encapsulate recording firewall events (text messages)
//	Notify clients as new messages are added and recycle buffer as needed
//	(preferably by sending email and/or flushing to disk).

#import "SentryLogger.h"
#import "SentryModel.h"
#import "SentryState.h"
#import "AppDelegate.h"
#import "PSServiceDictionary.h"
#import "IPTypes.h"
#import "NSDate_Extensions.h"
#import "SendEmailController.h"
#import "SendEmailServer.h"
#if !BUILD_AS_HELPER_TOOL
#import "DocumentSupport.h"
#endif

#define kLogBufferSize 32768

// Globals
NSString *SentryLoggerNotification = @"SentryLoggerNotification";

@interface SentryLogger (PrivateMethods)
- (void)sentryLogStop;
@end


@implementation SentryLogger
+ (SentryLogger *)sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[SentryLogger alloc] init];
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
		logTextLastMessage = nil;
		sentryLogInterval = 0;
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	¥ dealloc
// ---------------------------------------------------------------------------------
- (void)dealloc {
	[self sentryLogStop];
	[self logTextSaveForDate:nil];
	SendEmailController* controller = [SendEmailController sharedInstance];
	[controller abortWithTimeout:0.1];   // kill Send Email Server
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval)0.1]];
	[mText release];	mText = nil;
	[super dealloc];
}

// ---------------------------------------------------------------------------
//	¥ sentryLogStart
// ---------------------------------------------------------------------------
// Capture sentryLog information
- (NSTimeInterval)sentryLogStart
{
	BOOL showSeconds = NO;	// Can set to yes for debugging
	SentryState *sentryState = [[SentryModel sharedInstance] sentryState];
	// get desired interval
	NSString *str = [sentryState logUpdateInterval];
	NSTimeInterval seconds = (NSTimeInterval)[str intValue];
	if (([str hasSuffix:@"seconds"]) || (seconds == 10)) {
		// seconds, do nothing
		showSeconds = NO;
	}
	else if (([str hasSuffix:@"hours"]) || (seconds == 6)) {
		seconds *= 3600;	// hours
	}
	else {
		// minutes
		seconds *= 60;
	}
	// if interval does not match, reset timer
	if (seconds != sentryLogInterval) {
		if (sentryLogTimer) {
			sentryLogInterval = seconds;
			if (sentryLogInterval) 
				[sentryLogTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:sentryLogInterval]];
			NSString *text = nil;
			if (showSeconds) {
				text = [NSString stringWithFormat:
					@"{statusInfo = \"Save to disk interval changed to: %@ (%d seconds)\";}",str, (int)seconds];
			}
			else text = [NSString stringWithFormat:@"{statusInfo = \"Save to disk interval changed to: %@\";}",str];
			[[SentryLogger sharedInstance] logMessage:text];
		}
	}
	// kick off sentryLog timer if needed
	// default to 10 minutes
	if (!sentryLogTimer) {
		sentryLogInterval = seconds;
		sentryLogTimer = [NSTimer
			scheduledTimerWithTimeInterval:600
			target:self
			selector:@selector(sentryLogTimer:)
			userInfo:nil
			repeats:YES];
		if (sentryLogInterval) [sentryLogTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:sentryLogInterval]];
	}
	return seconds;
}

// ---------------------------------------------------------------------------
//	¥ sentryLogStop
// ---------------------------------------------------------------------------
// Capture sentryLog information
// Normally repeats every hour
- (void)sentryLogStop
{
	// cancel sentryLog timer
	[sentryLogTimer invalidate];	sentryLogTimer = nil;
}

// ---------------------------------------------------------------------------
//	¥ sentryLogTimer:
// ---------------------------------------------------------------------------
// Capture sentryLog information
// Normally repeats every sentryLog interval (default 60 minutes)
- (void)sentryLogTimer:(id)timer
{
	SentryState *sentryState = [[SentryModel sharedInstance] sentryState];
	// update log file with latest text
	NSString *str = [sentryState logUpdateInterval];
	NSTimeInterval seconds = [str intValue];	// could be 0 for "When full"
	if (([str hasSuffix:@"seconds"]) || (seconds = 10)) {
		// seconds, do nothing
	}
	else if (([str hasSuffix:@"hours"]) || (seconds = 6)) {
		seconds *= 3600;	// hours
	}
	else {
		// minutes
		seconds *= 60;
	}
	if (seconds) {
		if (-[logTextLastSaved timeIntervalSinceNow] > seconds) [self logTextSaveForDate:logTextLastMessage];
		[sentryLogTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
	}
}

// ---------------------------------------------------------------------------------
//	¥ logMessage:
// ---------------------------------------------------------------------------------
- (void)logMessage:(NSString *)message
{
	NSString* text;

	// log in user requested format
	text = [self formatLogMessage:message format:[self logFormat]];
	[self appendMessage:text];
}

// ---------------------------------------------------------------------------------
//	¥ appendMessage:
// ---------------------------------------------------------------------------------
// append string to log buffer
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
		dictionary = [NSDictionary dictionaryWithObject:message forKey:SentryLoggerNotification];
		[[NSNotificationCenter defaultCenter]
			postNotificationName:SentryLoggerNotification
			object:self
			userInfo:dictionary];
		// update log file with latest text
		NSTimeInterval seconds = [self sentryLogStart];
		if (seconds) {
			if (-[logTextLastSaved timeIntervalSinceNow] > seconds) {
				[self logTextSaveForDate:now];
				[logTextLastMessage release];	logTextLastMessage = nil;
			}
			else {
				// update last message time
				[logTextLastMessage release];	logTextLastMessage = nil;
				logTextLastMessage = [[NSCalendarDate date] retain];
			}
		}
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
		if ([[[[SentryModel sharedInstance] sentryState] emailSecurityLog] intValue]) {
			#ifdef IPNetRouter
			[self sendEmail:mText withSubject:@"--- IPNetRouter Security Log ---"];
			#else
			[self sendEmail:mText withSubject:@"--- IPNetSentry Security Log ---"];
			#endif
		}
		// clear log
		[mText setString:@""];
		// update for next time
		[logTextLastSaved release];
		logTextLastSaved = [[NSCalendarDate date] retain];
	}
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
	NSData* fileData;
	BOOL isDir;
	int logFormat = [[[[SentryModel sharedInstance] sentryState] logFormat] intValue];
	do {
		if ([[[[SentryModel sharedInstance] sentryState] saveToCheckBox] intValue]) {
			NSFileManager* fm = [NSFileManager defaultManager];
			filePath = kDefaultLogPath;
			// get file data
			if (logFormat == kLogFormat_ipfw) {
				fileData = [inText dataUsingEncoding:NSASCIIStringEncoding];
			}
			else {
				fileData = [inText dataUsingEncoding:NSUTF8StringEncoding];
			}
			// check for directory
			if ([fm fileExistsAtPath:filePath isDirectory:&isDir] && !isDir)
				dirPath = [filePath stringByDeletingLastPathComponent];
			else dirPath = filePath;
			// determine filepath
			if (!inDate) inDate = [NSCalendarDate date];
			if (logFormat == kLogFormat_propertyList) {
				dateString = [inDate descriptionWithCalendarFormat:@"security log %Y-%m-%d.plist"];
			}
			else if (logFormat == kLogFormat_ipfw) {
				dateString = [inDate descriptionWithCalendarFormat:@"security.log"];
			}
			else {
				dateString = [inDate descriptionWithCalendarFormat:@"security log %Y-%m-%d.txt"];
			}
			filePath = [dirPath stringByAppendingPathComponent:dateString];			
			// does file already exist?
			if (![fm fileExistsAtPath:filePath]) {
				// does directory exist?
				if (![fm fileExistsAtPath:dirPath]) {
					// no, try to create directory
					[fm createDirectoryAtPath:dirPath attributes:nil];
				}
				// have directory, try to create file
				if (![fm createFileAtPath:filePath contents:fileData attributes:nil]) {
					NSLog(@"SentryLogger: unable to create file at path: %@",filePath);
					break;
				}
				// create alias with name "security log today.txt"
				// - remove previous if any
				BOOL status;
				NSString* todayPath = [dirPath stringByAppendingPathComponent:@"security log today.txt"];
				status = [fm removeFileAtPath:todayPath handler:nil];
				// create link to today's log file
				status = [fm createSymbolicLinkAtPath:todayPath pathContent:filePath];
				if (!status) NSLog(@"unable to create symbolic link for %@",filePath);
			}
			else {
				// yes, append to existing contents
				NSFileHandle* fh = [NSFileHandle fileHandleForWritingAtPath:filePath];
				if (fh == nil) {
					NSLog(@"SentryLogger: unable to access file at path: %@",filePath);
					break;
				}
				[fh seekToEndOfFile];
				[fh writeData:fileData];
			}
		}
	} while (false);
}

// ---------------------------------------------------------------------------------
//	¥ writeToPFile
// ---------------------------------------------------------------------------------
// write current log text to file if enabled
- (void)writeToPFile:(NSString *)inText forDate:(NSCalendarDate *)inDate
{
	NSString* filePath;
	NSString* dirPath;
	NSString* dateString;
	NSData* fileData;
	BOOL isDir;
	do {
		if ([[[[SentryModel sharedInstance] sentryState] saveToCheckBox] intValue]) {
			NSFileManager* fm = [NSFileManager defaultManager];
			filePath = kDefaultLogPath;
			// get file data
			fileData = [inText dataUsingEncoding:NSUTF8StringEncoding];
			// check for directory
			if ([fm fileExistsAtPath:filePath isDirectory:&isDir] && !isDir)
			dirPath = [filePath stringByDeletingLastPathComponent];
			else dirPath = filePath;
			// determine filepath
			if (!inDate) inDate = [NSCalendarDate date];
			dateString = [inDate descriptionWithCalendarFormat:@"security log %Y-%m-%d.plist"];
			filePath = [dirPath stringByAppendingPathComponent:dateString];			
			// does file already exist?
			if (![fm fileExistsAtPath:filePath]) {
				// does directory exist?
				if (![fm fileExistsAtPath:dirPath]) {
					// no, try to create directory
					[fm createDirectoryAtPath:dirPath attributes:nil];
				}
				// have directory, try to create file
				if (![fm createFileAtPath:filePath contents:fileData attributes:nil])
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
				[fh writeData:fileData];
			}
		}
	} while (false);
}

// ---------------------------------------------------------------------------------
//	¥ sendEmail
// ---------------------------------------------------------------------------------
// send current log text as email if enabled
- (BOOL)sendEmail:(NSString *)inText withSubject:(NSString *)inSubject
{
	BOOL returnValue = NO;
	NSString* mailToAddress;
	NSString* emailFromField;
	NSString* emailNameField;
	do {	
		mailToAddress = [[[SentryModel sharedInstance] sentryState] emailToField];
		if (!mailToAddress) {
			NSLog(@"SentryLogger: mail to address has not been configured");
			returnValue = NO;
			break;
		}
		emailFromField = [[[AppDelegate sharedInstance] prefs]
			objectForKey:kPreferences_emailFromField];
		emailNameField = [[[AppDelegate sharedInstance] prefs]
			objectForKey:kPreferences_emailNameField];
		if (emailFromField && emailNameField) {
			emailFromField = [NSString stringWithFormat:@"%@ <%@>",emailNameField,emailFromField];
		}
		// create server as thread object if needed
		{
			NSMutableDictionary* message = [NSMutableDictionary dictionaryWithObjectsAndKeys:
				inSubject,@"Subject",
				mailToAddress,@"To",
				[[NSDate psDate] description],@"Date",
				inText, @"Body",
				nil];
			if (emailFromField) [message setObject:emailFromField forKey:@"From"];
			
			SendEmailController* controller = [SendEmailController sharedInstance];
			//[controller setDelegate:self];
			// create server if needed
			[controller startService:kSendEmail withObject:message];
			returnValue = YES;
		}
	} while (false);
	return returnValue;
}


// ---------------------------------------------------------------------------------
//	¥ string
// ---------------------------------------------------------------------------------
- (NSString *)string
{
	return mText;
}

// ---------------------------------------------------------------------------------
//	¥ logFormat
// ---------------------------------------------------------------------------------
// return integer logFormat: kLogFormat_propertyList, kLogFormat_text, kLogFormat_ipfw
- (int)logFormat
{
	SentryState* sentryState;
	int logFormat;
	// notice we might try to log a message before a sentryState document has been read
	sentryState = [[SentryModel sharedInstance] sentryState];
	if (sentryState) logFormat = [[sentryState logFormat] intValue];
	else logFormat = [[[[AppDelegate sharedInstance] prefs] objectForKey:kPreferences_logFormat] intValue];

	return logFormat;
}

// ---------------------------------------------------------------------------------
//	¥ formatLogMessage
// ---------------------------------------------------------------------------------
- (NSString *)formatLogMessage:(NSString *)message
{
	return [self formatLogMessage:message format:[self logFormat]];
}

// ---------------------------------------------------------------------------------
//	¥ formatLogMessage:format:
// ---------------------------------------------------------------------------------
- (NSString *)formatLogMessage:(NSString *)message format:(int)logFormat
{
	NSString* statusInfo;
	NSString* logText = nil;
	NSString* packetText = @"";
	NSDictionary* logDictionary;
	NSRange range;
	NSString* actionStr;
	NSString* subActionStr;
	NSString* parameterStr;
	NSString* codeStr;
	NSString* protocolStr;
	
	// Is it a property list?
	if ([message hasPrefix:@"{"]) {
		// format as requested
		NS_DURING
			switch (logFormat) {
				// plist
				case kLogFormat_propertyList:				
					logText = [NSString stringWithFormat:@"\n{ time = \"%@\";%@,",[[NSDate psDate] descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S" timeZone:nil locale:nil], [message substringFromIndex:1]];
					break;
				// text
				case kLogFormat_text:
					// convert to dictionary		
					logDictionary = [message propertyList];
					statusInfo = [logDictionary objectForKey:@"statusInfo"];
					if (statusInfo) {
						logText = [NSString stringWithFormat:@"\n%@  %@",
							[[NSDate psDate] descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S" timeZone:nil locale:nil],
							statusInfo];
					}
					else {
						statusInfo = [logDictionary objectForKey:@"statusInfoAppend"];
						if (statusInfo) logText = [NSString stringWithFormat:@"\n%@",statusInfo];
					}
					if (!statusInfo) {
						if ([logDictionary objectForKey:@"rule"]) {
							// handle as filter event
							parameterStr = [logDictionary objectForKey:@"parameter"];
							if (!parameterStr) parameterStr = @"";
							subActionStr = [logDictionary objectForKey:@"subAction"];
							if (subActionStr) subActionStr = [NSString stringWithFormat:@" (%@)",subActionStr];
							else subActionStr = @"";
							logText = [NSString stringWithFormat:@"\n%@  %@%@ %@",
								[[NSDate psDate] descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S" timeZone:nil locale:nil],
								[logDictionary objectForKey:@"action"],
								subActionStr,
								[logDictionary objectForKey:@"rule"]
							];
							if ((protocolStr = [logDictionary objectForKey:@"protocol"])) {
								protocolStr = [self formatProtocol:protocolStr];
								packetText = [NSString stringWithFormat:@"%@ %@ -> %@ %@ via %@ %@ bytes",
									protocolStr,
									[logDictionary objectForKey:@"source"],
									[logDictionary objectForKey:@"destination"],
									
									[logDictionary objectForKey:@"direction"],
									[logDictionary objectForKey:@"interface"],
									[logDictionary objectForKey:@"byteCount"]
								];
							}
							logText = [NSString stringWithFormat:@"%@  %@  %@", logText, packetText, parameterStr];
						}
						else {
							logText = [NSString stringWithFormat:@"\n{ time = \"%@\";%@,",[[NSDate psDate] descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S" timeZone:nil locale:nil], [message substringFromIndex:1]];
						}
					}
					break;
				// ipfw
				case kLogFormat_ipfw:
					// convert to dictionary		
					logDictionary = [message propertyList];
					statusInfo = [logDictionary objectForKey:@"statusInfo"];
					if (!statusInfo) statusInfo = [logDictionary objectForKey:@"statusInfoAppend"];
					if (statusInfo) break;  // nothing to show in this format
					// handle as filter event
					actionStr = @"Accept";
					range.length = 0;
					range = [[logDictionary objectForKey:@"action"] rangeOfString:@"dropped"];
					if (range.length) actionStr = @"Deny";
					codeStr = [logDictionary objectForKey:@"rule"];
					if (![codeStr length]) break;	// nothing to show in this format
					range = [codeStr rangeOfString:@" "];
					if (range.length) codeStr = [codeStr substringToIndex:range.location];
					NSString *hostName = @"";
					{
						char name[128];
						int result = gethostname(name, 128);
						if (result == 0) hostName = [NSString stringWithFormat:@"%s",name];
					}
#ifdef IPNetRouter
					logText = [NSString stringWithFormat:@"\n%@ %@ IPNetRouter_NKE ipfw: %@ %@",
						[[NSDate psDate] descriptionWithCalendarFormat:@"%b %d %H:%M:%S" timeZone:nil locale:nil],
						hostName,
						codeStr,
						actionStr
					];
#else
					logText = [NSString stringWithFormat:@"\n%@ %@ IPNetSentry_NKE ipfw: %@ %@",
						[[NSDate psDate] descriptionWithCalendarFormat:@"%b %d %H:%M:%S" timeZone:nil locale:nil],
						hostName,
						codeStr,
						actionStr
					];
#endif
					if ([logDictionary objectForKey:@"protocol"]) {
						packetText = [NSString stringWithFormat:@"%@ %@ %@ %@ via %@",
							[logDictionary objectForKey:@"protocol"],
							[logDictionary objectForKey:@"source"],
							[logDictionary objectForKey:@"destination"],
							
							[logDictionary objectForKey:@"direction"],
							[logDictionary objectForKey:@"interface"]
						];
					}
					else {
						packetText = @"";					
					}
					logText = [NSString stringWithFormat:@"%@ %@", logText, packetText];
					break;
			}   // switch (logFormat)
		NS_HANDLER
			NSLog(@"SentryLogger formatLogMessage - failed to convert message to dictionary:");
			NSLog(@"%@",message);
		NS_ENDHANDLER
	}
	else {
		// not a plist, just prepend date if text begins with \n
		if ([message hasPrefix:@"\n"]) {
			message = [message substringFromIndex:1];
			logText = [NSString stringWithFormat:@"\n{ time = \"%@\"; text = \"%@\"; },",
				[[NSDate psDate] descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S" timeZone:nil locale:nil],
				message];
		}
		//else logText = message;
		else {
			logText = [NSString stringWithFormat:@"\n{ text = \"%@\"; },",
				message];
		}
	}
	return logText;
}

// ---------------------------------------------------------------------------------
//	¥ formatProtocol
// ---------------------------------------------------------------------------------
- (NSString *)formatProtocol:(NSString *)inString
{
	NSString* protocolStr = inString;
	if ([protocolStr hasPrefix:@"ICMP"]) {
		// expand ICMP type and code
		NSString* str1;
		NSString* str2;
		NSRange range;
		int type, code;
		range = [protocolStr rangeOfString:@":"];
		if (range.length) {
			str1 = [protocolStr substringFromIndex:range.location+1];
			range = [str1 rangeOfString:@","];
			if (range.length) {
				str2 = [str1 substringFromIndex:range.location+1];
				str1 = [str1 substringToIndex:range.location];
				type = [str1 intValue];
				code = [str2 intValue];
				str1 = [[PSServiceDictionary sharedInstance] nameForICMPType:type];
				str2 = [[PSServiceDictionary sharedInstance] nameForICMPCode:code];
				if (type == kIcmpTypeDestUnreachable) {
					protocolStr = [NSString stringWithFormat:@"%@ (%@,%@)",
						protocolStr, str1, str2];
				}
				else {
					protocolStr = [NSString stringWithFormat:@"%@ (%@)",
						protocolStr, str1];									
				}
			}
		}
	}	// if ([protocolStr hasPrefix:@"ICMP"])
	return protocolStr;
}
@end
