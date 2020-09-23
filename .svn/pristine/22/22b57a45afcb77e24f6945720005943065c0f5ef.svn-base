//
//  MyGrowlDelegate.h
//  IPNetRouterX
//
//  Created by Peter Sichel on 4/2/07.
//  Copyright 2007 Sustainable Softworks, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Growl/GrowlApplicationBridge.h>


@interface MyGrowlDelegate : NSObject <GrowlApplicationBridgeDelegate> {
	NSDictionary* alertInfo;
}
+ (MyGrowlDelegate *) sharedInstance;
- (NSDictionary *)alertInfo;
- (void)setAlertInfo:(NSDictionary *)value;

- (NSDictionary *) registrationDictionaryForGrowl;
- (NSString *) applicationNameForGrowl;
//- (void) growlNotificationWasClicked:(id)clickContext;
//- (void) growlNotificationTimedOut:(id)clickContext;
- (void) notifyWithDictionary:(NSDictionary *)userInfo;
@end

#define kGrowlIsReady	@"growlIsReady"
#define kTriggerAlert	@"TriggerAlert"
#define kTriggerAlertAddress	@"TriggerAlertAddress"