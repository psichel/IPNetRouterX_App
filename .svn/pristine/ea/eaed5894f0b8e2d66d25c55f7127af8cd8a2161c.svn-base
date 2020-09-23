//
//  PSURL.h
//  IPNetMonitorX
//
//  Created by psichel on Tues Oct 30 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Encapsulates building and parsing URL strings
//  <scheme>://<net_loc>/<path>;<params>?<query>#<fragment>
//             <name>@<host>:<port>
//
//  Does not support <NSCopying> since we can just pass
//  the corresponding URL string.

#import <Foundation/Foundation.h>

@interface PSURL : NSObject {
    NSString*	scheme;
    NSString*	name;
    NSString*	host;
    NSString*	port;
    NSString*	path;
    NSMutableDictionary*	params;
    NSString*	query;
    NSString*	fragment;
}
+ (PSURL *)urlWithString:(NSString *)inString;
- (id)init;
// get components
- (NSString *)stringValue;
- (NSString *)scheme;
- (NSString *)name;
- (NSString *)host;
- (NSString *)port;
- (NSString *)path;
- (NSString *)paramValueForKey:(NSString *)key;
- (NSString *)query;
- (NSString *)fragment;
// set components
// setURL returns nil on success or an error message on failure 
- (void)setStringValue:(NSString *)inString;
- (void)setScheme:(NSString *)inString;
- (void)setName:(NSString *)inString;
- (void)setHost:(NSString *)inString;
- (void)setPort:(NSString *)inString;
- (void)setPath:(NSString *)inString;
- (void)setParamValue:(NSString *)value forKey:(NSString *)key;
- (void)setQuery:(NSString *)inString;
- (void)setFragment:(NSString *)inString;
// print object
- (NSString *)description;
@end
