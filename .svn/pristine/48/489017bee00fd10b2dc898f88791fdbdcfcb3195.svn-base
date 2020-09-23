//
//  AddressScanUserInfo.h
//  IPNetMonitorX
//
//  Created by Peter Sichel on 3/16/09.
//  Copyright 2009 Sustainable Softworks. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AddressScanUserInfo : NSObject {
	NSMutableDictionary *infoD;
}
+ (AddressScanUserInfo *)sharedInstance;	// returns a shared instance of the class
- (void)save;
- (void)restore;
// accessors
- (NSString *)nameForKey:(NSString *)key;
- (void)setName:(NSString *)value forKey:(NSString *)key;
- (NSString *)commentForKey:(NSString *)key;
- (void)setComment:(NSString *)value forKey:(NSString *)key;
@end

#define kAddressScanUserInfo_name		@"AddressScanUserInfo"
#define kUnitSeparator					@"<US>"
