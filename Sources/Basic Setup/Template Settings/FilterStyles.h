//
//  FilterStyles.h
//  IPNetSentryX
//
//  Created by Peter Sichel on 10/14/05.
//  Copyright 2005 Sustainable Softworks. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FilterStyles : NSObject {
	NSDictionary* stylesDictionary;
}
+ (FilterStyles *)sharedInstance;
- (NSDictionary *)stylesDictionary;
@end

// dictionary schema
#define kStyleTitle			@"title"
#define kStyleIdentifier	@"identifier"
#define kStyleType			@"type"

#define kStyleType_blacklist		@"blacklist"
#define kStyleType_deny				@"deny"
#define kStyleType_denyByAddress	@"denyByAddress"
#define kStyleType_denyByContent	@"denyByContent"
#define kStyleType_allowByAddress	@"allowByAddress"
#define kStyleType_allowByTime		@"allowByTime"
#define kStyleType_reserveBandwidth	@"reserveBandwidth"
#define kStyleType_limitBandwidth	@"limitBandwidth"
#define kStyleType_notification		@"notification"
#define kStyleType_allow			@"allow"

#define kStyle_blacklistDuration	@"blacklistDuration"
#define kStyle_addressList			@"addressList"
#define kStyle_urlKeyword			@"urlKeyword"
#define kStyle_urlField				@"urlField"
#define kStyle_lookFor				@"lookFor"
#define kStyle_lookField			@"lookField"
#define kStyle_startOffset			@"startOffset"
#define kStyle_searchLength			@"searchLength"
#define kStyle_searchRelative		@"searchRelative"
#define kStyle_continueWith			@"continueWith"

#define kStyle_after				@"after"
#define kStyle_afterTime			@"afterTime"
#define kStyle_until				@"until"
#define kStyle_untilTime			@"untilTime"
#define kStyle_timeOfDay			@"timeOfDay"
#define kStyle_daysOfWeek			@"daysOfWeek"
#define kStyle_daysOfWeekMask		@"daysOfWeekMask"

#define kStyle_reserveIn			@"reserveIn"
#define kStyle_reserveInAmount		@"reserveInAmount"
#define kStyle_reserveInAvailable	@"reserveInAvailable"
#define kStyle_reserveOut			@"reserveOut"
#define kStyle_reserveOutAmount		@"reserveOutAmount"
#define kStyle_reserveOutAvailable	@"reserveOutAvailable"

#define kStyle_limitIn				@"limitIn"
#define kStyle_limitInAmount		@"limitInAmount"
#define kStyle_limitOut				@"limitOut"
#define kStyle_limitOutAmount		@"limitOutAmount"

#define kStyle_notificationLog		@"notificationLog"
#define kStyle_notificationAlert	@"notificationAlert"
#define kStyle_notificationEmail	@"notificationEmail"
#define kStyle_emailTo				@"emailT"
#define kStyle_notificationScript	@"notificationScript"
#define kStyle_scriptPath			@"scriptPath"
#define kStyle_denyOthers			@"denyOthers"

