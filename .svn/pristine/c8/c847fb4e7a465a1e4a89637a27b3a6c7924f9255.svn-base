//
//  FirewallOptions.h
//  IPNetSentryX
//
//  Created by Peter Sichel on 10/14/05.
//  Copyright 2005 Sustainable Softworks. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FirewallOptions : NSObject {
	NSDictionary* optionsDictionary;
}
+ (FirewallOptions *)sharedInstance;
- (NSDictionary *)optionsDictionary;
@end

// dictionary schema
#define kOptionDescription	@"description"
#define kOptionIdentifier	@"identifier"
#define kOptionProduct		@"product"
#define kOptionType			@"type"

#define kOptionIdentifier_blockIPv6				@"blockIPv6"
#define kOptionIdentifier_connectionLogging		@"connectionLogging"
#define kOptionIdentifier_disableAlerts			@"disableAlerts"
#define kOptionIdentifier_automaticFailover		@"automaticFailover"
#define kOptionIdentifier_loadBalance			@"loadBalance"
#define kOptionIdentifier_sourceAwareRouting	@"sourceAwareRouting"

#define kOptionProduct_ipnr	@"ipnr"
#define kOptionProduct_ipns	@"ipns"

#define kOptionType_bool	@"bool"
#define kOptionType_value	@"value"