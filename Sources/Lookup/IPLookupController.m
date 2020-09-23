#import "IPLookupController.h"
#import "LookupServer.h"
#import "IPSupport.h"
#import "PingHistory.h"
#import "PSSharedDictionary.h"

@implementation IPLookupController

//- init and dealloc
- (id) init {
    if (self = [super init]) {
        mRequestInProgress = NO;
        mClient = nil;
        mResultString = nil;
		mOption = 0;
		mLookupRequest = nil;
		mLookupQueue = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc {
	[mClient setCallbackTarget:nil];
	[mClient release];  mClient = nil;
    [mResultString release];  mResultString = nil;
	[mLookupRequest release]; mLookupRequest = nil;
	[mLookupQueue release];	mLookupQueue = nil;
    [super dealloc];
}
#pragma mark - accessors -
- (NSString *)result { return mResultString; };
- (void)setResult:(NSString *)aString {
    [aString retain];
    [mResultString release];
    mResultString = aString;
}

- (NSDictionary *)lookupRequest { return mLookupRequest; };
- (void)setLookupRequest:(NSDictionary *)value {
	[value retain];
	[mLookupRequest release];
	mLookupRequest = value;
}

- (int)option { return mOption; }
- (void)setOption:(int)value {
	mOption = value;
}

#pragma mark - actions -
// ---------------------------------------------------------------------------
//	¥ lookup:
// ---------------------------------------------------------------------------
- (BOOL)lookup:(NSString *)aString callbackObject:(id)anObserver
    withSelector:(SEL)method
    userInfo:(NSDictionary *)userInfo;
{
	NSString* str;
    BOOL returnValue = NO;
    
    do {
		if (!aString) break;
		// capture request in dictionary
		NSDictionary* lookupRequest = [NSDictionary dictionaryWithObjectsAndKeys:
			aString, kLookup_string,
			anObserver, kLookup_target,
			[NSNumber numberWithInt:(int)method], kLookup_selectorNum,
			userInfo, kLookup_userInfo,
			nil];

		// check DNS nameCache
		str = cacheObjectForKey([lookupRequest objectForKey:kLookup_string]);
		if (str) {
			[self notifyClient:lookupRequest withObject:str];
			returnValue = YES;
			break;
		}
 
		// check if server is busy
		if (mRequestInProgress) {
			// queue this request and get out
			[mLookupQueue addObject:lookupRequest];
			//NSLog(@"Queue lookup request %@",[lookupRequest objectForKey:kLookup_string]);
			returnValue = YES;
			break;
		}
		
		returnValue = [self doRequest:lookupRequest];
    } while (false);
    return returnValue;
}

// ---------------------------------------------------------------------------
//	¥ notifyClient:withObject:
// ---------------------------------------------------------------------------
- (BOOL)doRequest:(NSDictionary *)lookupRequest
{
    NSString* url;
    BOOL returnValue = NO;
    
    do {
		// don't allow multiples
        if (mRequestInProgress) break;
        mRequestInProgress = YES;
        // save request information
		[self setLookupRequest:lookupRequest];
		//NSLog(@"Begin lookup request %@",[lookupRequest objectForKey:kLookup_string]);		
        // lookup://name
        url = [NSString stringWithFormat:@"lookup://%@",[lookupRequest objectForKey:kLookup_string]];
        
        // create Lookup Server object running as a detached thread if needed
        if (!mClient) {
            mClient = [[PsClient alloc] init];
			[mClient setCallbackTarget:self];
			[mClient setServerClass:[LookupServer class]];
        }
		if (![mClient isConnected]) [mClient createNewServer:[LookupServer class]];
        // start test
        if ([mClient isConnected]) {
            // launch service
            [mClient startService:url withObject:nil];
            returnValue = YES;
        }
        else mRequestInProgress = NO;
    } while (false);
    return returnValue;
}

- (void)testComplete {
    mRequestInProgress = NO;
	[self setLookupRequest:nil];
	// check for any lookupRequests pending
	if ([mLookupQueue count]) {
		NSDictionary* lookupRequest = [mLookupQueue objectAtIndex:0];
		// retain before removing from list
		[self setLookupRequest:lookupRequest];
		[mLookupQueue removeObjectAtIndex:0];
		// do the request
		[self doRequest:lookupRequest];
		//NSLog(@"do pending lookup request");
	}
}

- (void)abort {
	[mClient abort];
}

- (BOOL)ready {
    return !mRequestInProgress;
}

// ---------------------------------------------------------------------------
//	¥ notifyClient:withObject:
// ---------------------------------------------------------------------------
- (void)notifyClient:(NSDictionary *)lookupRequest withObject:(NSString *)value
{
	// add observer to receive notification
	[[NSNotificationCenter defaultCenter] addObserver:[lookupRequest objectForKey:kLookup_target] 
		selector:(SEL)[[lookupRequest objectForKey:kLookup_selectorNum] intValue]
		name:kIPLookupControllerNotification 
		object:self];		

	// callback with result
	[self setResult:value];
	[[NSNotificationCenter defaultCenter]
		postNotificationName:kIPLookupControllerNotification
		object:self
		userInfo:[lookupRequest objectForKey:kLookup_userInfo]];
		
	// remove observer
	[[NSNotificationCenter defaultCenter] removeObserver:[lookupRequest objectForKey:kLookup_target]
		name:kIPLookupControllerNotification
		object:self];
}

// -- <ControllerFromThread> --
// ---------------------------------
- (oneway void)receiveDictionary:(NSDictionary *)dictionary
// update parameters passed in dictionary
// Uses key as the name of a class or instance and sets its value
{
    NSEnumerator *enumerator = [dictionary keyEnumerator];
    id key;
    id object;

	if ([[dictionary objectForKey:PSAction] isEqualTo:PSServerFinishedNotification]) {
		[self testComplete];
	}		
	else {
		while ((key = [enumerator nextObject])) { 
			/* code that uses the returned key */
			if (![key isKindOfClass:[NSString class]]) continue; 
			object = [dictionary objectForKey:key];
			if ([object isKindOfClass:[NSString class]]) {	// assign string values
				if (NO);
				// status
				else if ([key isEqualTo:kStatusInfo]) {
					if (mOption != kOption_resultOnly) {
						[self setResult:object];
						if ([mResultString length]) [self notifyClient:mLookupRequest withObject:object];
					}
				}
				else if ([key isEqualTo:kLookupComplete]) {
					[self testComplete];
				}
				// output
				else if ([key isEqualTo:kResultField]) {
					[self setResult:object];
					[self notifyClient:mLookupRequest withObject:object];
					// cache result
					cacheSetObjectForKey(object, [mLookupRequest objectForKey:kLookup_string]);
				}
				else if ([key isEqualTo:kNoAddressFound]) {
					[self setResult:object];
					if ([mResultString length]) [self notifyClient:mLookupRequest withObject:object];
				}
			}
		}
	}
}

@end
