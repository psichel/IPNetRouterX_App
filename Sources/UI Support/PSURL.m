//
//  PSURL.m
//  IPNetMonitorX
//
//  Created by psichel on Tues Oct 30 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Encapsulates building and parsing URL strings
//  <scheme>://<net_loc>/<path>;<params>?<query>#<fragment>
//             <name>@<host>:<port>
//	interprets <scheme>://<target> as host, returns name only if "@" found
//
//  Does not support <NSCopying> since we can just pass
//  the corresponding URL string.
//  Accessors can return nil.

#import "PSURL.h"

@implementation PSURL
+ (PSURL *)urlWithString:(NSString *)inString
{
	PSURL* url = nil;
	url = [[PSURL alloc] init];
	[url setStringValue:inString];
	[url autorelease];
	return url;
}

- (id)init {
    if (self = [super init]) {
        scheme = nil;
        name = nil;
        host = nil;
        port = nil;
        path = nil;
        params = nil;
        query = nil;
        fragment = nil;       
    }
    return self;
}
- (void)dealloc {
    if (scheme) [scheme release];
    if (name) [name release];
    if (host) [host release];
    if (port) [port release];
    if (path) [path release];
    if (params) [params release];
    if (query) [query release];
    if (fragment) [fragment release];
    [super dealloc];
}

// get components
- (NSString *)stringValue
{
    NSMutableString* url=nil;
    NSEnumerator* en;
    NSString* key;
    NSString* object;
    
    if (scheme != nil) {
        url = [NSMutableString stringWithFormat:@"%@://",scheme];
        if ([name length]) [url appendString:[NSString stringWithFormat:@"%@@",name]];
        if (host != nil) [url appendString:host];
        if (port != nil) [url appendString:[NSString stringWithFormat:@":%@",port]];
        if (path != nil) [url appendString:[NSString stringWithFormat:@"/%@",path]];
    
        if (params != nil) {
            en = [params keyEnumerator];
            while ((key = [en nextObject])) {
                object = [params objectForKey:key];
                [url appendString:[NSString stringWithFormat:@";%@=%@",key,object]];
            }
        }
    }
    return url;
}

- (NSString *)scheme
{
    return scheme;
}

- (NSString *)name
{
    return name;
}

- (NSString *)host
{
    return host;
}

- (NSString *)port
{
    return port;
}

- (NSString *)path
{
    return path;
}

- (NSString *)paramValueForKey:(NSString *)key
{
    return [params objectForKey:key];
}

- (NSString *)query
{
    return query;
}

- (NSString *)fragment
{
    return fragment;
}


// set components
//  <scheme>://<net_loc>/<path>;<params>?<query>#<fragment>
//             <name>@<server>:<port>
- (void)setStringValue:(NSString *)inString
{
    do {
        NSString* url;
        NSRange range;
        NSArray* list;
        NSEnumerator* en;
        NSString* key;
        NSString* object;
        // extract scheme
        url = inString;
		// remove standard delimiters if present
		if ([url hasPrefix:@"<"]) url = [url substringFromIndex:1];
		if ([url hasPrefix:@"URL:"]) url = [url substringFromIndex:4];
		if ([url hasSuffix:@">"]) url = [url substringToIndex:[url length]-1];
        // extract scheme
        range = [url rangeOfString:@"://"];
        if (range.length != 0) {
            [self setScheme:[url substringToIndex:range.location]];
            url = [url substringFromIndex:range.location+3];         
        }
        else {
            range = [url rangeOfString:@":"];
            if (range.length != 0) {
                [self setScheme:[url substringToIndex:range.location]];
                url = [url substringFromIndex:range.location+1];         
            }
            else {
                // treat entire URL as scheme
				[self setScheme:inString];
				// allow name@host below
            }
        }
        // MSIE may append any empty path "/" after the ;param, remove it
        range = [url rangeOfString:@";"];
        if (range.length) {
            range = [url rangeOfString:@"/" options:NSBackwardsSearch];
            if ((range.length) && (range.location == [url length]-1))
                url = [url substringToIndex:range.location];
        }
        
        // remove #fragment if present
        range = [url rangeOfString:@"#"];
        if (range.length != 0) {
            [self setFragment:[url substringFromIndex:range.location+1]];
            url = [url substringToIndex:range.location];
        }
        // remove ?query if present
        range = [url rangeOfString:@"?"];
        if (range.length != 0) {
            [self setQuery:[url substringFromIndex:range.location+1]];
            url = [url substringToIndex:range.location];
        }        
        // get list of parameters
        list = [url componentsSeparatedByString:@";"];
        // store parameters in dictionary
        en = [list objectEnumerator];
        url = [en nextObject];	// first object is remaining url
        while ((key = [en nextObject])) {
            range = [key rangeOfString:@"="];
            if (range.length > 0) {
                object = [key substringFromIndex:range.location+1];
                key = [key substringToIndex:range.location];
                [self setParamValue:object forKey:key];
            }
        }
        // extract name@ if present
        range = [url rangeOfString:@"@"];
        if (range.length != 0) {
            [self setName:[url substringToIndex:range.location]];
            url = [url substringFromIndex:range.location+1];         
        }
        // remove /path if present
        range = [url rangeOfString:@"/"];
        if (range.length != 0) {
			[self setPath:[url substringFromIndex:range.location+1]];
            url = [url substringToIndex:range.location];
        }        
        // extract :port if present
		// IPv6 address will be enclosed in [] if :port is present
        range = [url rangeOfString:@":" options:NSBackwardsSearch];
        if (range.length != 0) {
            // check for ] indicating an IPv6 address
			NSRange range2;
			NSString* str = [url substringToIndex:range.location];
			range2 = [str rangeOfString:@"]" options:NSBackwardsSearch];
			if (range2.length) {
				// found ], extract :port from IPv6 address
				[self setPort:[url substringFromIndex:range.location+1]];
				url = [url substringToIndex:range.location];
			}
			else {
				// check for 2nd : indicating an IPv6 address without []
				range2 = [str rangeOfString:@":" options:NSBackwardsSearch];
				if (range2.length == 0) {
					[self setPort:[url substringFromIndex:range.location+1]];
					url = [url substringToIndex:range.location];
				}
			}
        }        
        // host should be all that is left
        [self setHost:url];
    } while (false);
}

- (void)setScheme:(NSString *)inString
{
    [inString retain];
    [scheme release];
    scheme = inString;
}

- (void)setName:(NSString *)inString
{
    if ([inString length] == 0) inString = nil;
    [inString retain];
    [name release];
    name = inString;
}

- (void)setHost:(NSString *)inString
{
    if ([inString length] == 0) inString = nil;
    [inString retain];
    [host release];
    host = inString;
}

- (void)setPort:(NSString *)inString
{
    [inString retain];
    [port release];
    port = inString;
}

- (void)setPath:(NSString *)inString
{
    [inString retain];
    [path release];
    path = inString;
}

- (void)setParamValue:(NSString *)value forKey:(NSString *)key;
{
    // create parameter dictionary if needed
    if (params == nil) {
        params = [NSMutableDictionary dictionaryWithObject:value forKey:key];
        [params retain];
    }
    else {
        [params setObject:value forKey:key];
    }
}

- (void)setQuery:(NSString *)inString
{
    [inString retain];
    [query release];
    query = inString;
}

- (void)setFragment:(NSString *)inString
{
    [inString retain];
    [fragment release];
    fragment = inString;
}

// print object
- (NSString *)description {
    return [self stringValue]; 
}

@end
