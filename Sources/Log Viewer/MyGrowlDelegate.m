//
//  MyGrowlDelegate.m
//  IPNetRouterX
//
//  Created by Peter Sichel on 4/2/07.
//  Copyright 2007 Sustainable Softworks, Inc. All rights reserved.
//

#import "MyGrowlDelegate.h"
#import "PSSharedDictionary.h"
#import "AppDelegate.h"
#import "SentryState.h"		// kPreferences_disableAlerts
#import "AlertPanelDelegate.h"


@interface MyGrowlDelegate (PrivateMethods)
- (void) alertWithDictionary:(NSDictionary *)userInfo;
@end

@implementation MyGrowlDelegate
+ (MyGrowlDelegate *)sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[MyGrowlDelegate alloc] init];
	}
	return sharedTask;
}

// ---------------------------------------------------------------------------------
//	• init
// ---------------------------------------------------------------------------------
- (id)init
{
    if (self = [super init]) {
        // initialize our instance variables
		alertInfo = nil;
		[GrowlApplicationBridge setGrowlDelegate:self];
    }
    return self;
}

// ---------------------------------------------------------------------------------
//	• dealloc
// ---------------------------------------------------------------------------------
- (void)dealloc {
	[self setAlertInfo:nil];
	[super dealloc];
}

// ---------------------------------------------------------------------------------
//	• alertInfo
// ---------------------------------------------------------------------------------
- (NSDictionary *)alertInfo { return alertInfo; }
- (void)setAlertInfo:(NSDictionary *)value
{
	[value retain];
	[alertInfo release];
	alertInfo = value;
}


// ---------------------------------------------------------------------------------
//	• registrationDictionaryForGrowl
// ---------------------------------------------------------------------------------
- (NSDictionary *) registrationDictionaryForGrowl
{
	NSDictionary *returnValue = nil;
	NSArray* notificationNames;
	
	notificationNames = [NSArray arrayWithObjects:
		kTriggerAlert,
		nil];
	
	returnValue = [NSDictionary dictionaryWithObjectsAndKeys:
		notificationNames, GROWL_NOTIFICATIONS_ALL,
		notificationNames, GROWL_NOTIFICATIONS_DEFAULT,
		nil];
	
	return returnValue;
}

// ---------------------------------------------------------------------------------
//	• applicationNameForGrowl
// ---------------------------------------------------------------------------------
- (NSString *) applicationNameForGrowl
{
	return @"IPNetRouterX";
}

#if 0
// ---------------------------------------------------------------------------------
//	• growlNotificationWasClicked
// ---------------------------------------------------------------------------------
- (void) growlNotificationWasClicked:(id)clickContext
{
	NSLog(@"growlNotificationWasClicked");
	// if the notification was clicked and we're running with a UI,
	// we assume the user wants more info
	if ([clickContext isEqualTo:kTriggerAlert]) {
		if ([clickContext isEqualTo:[alertInfo objectForKey:GROWL_NOTIFICATION_CLICK_CONTEXT]])
			[self alertWithDictionary:alertInfo];
	}
}

- (void) growlNotificationTimedOut:(id)clickContext
{
	NSLog(@"growlNotificationTimedOut");
}
#endif

// ---------------------------------------------------------------------------------
//	• notifyWithDictionary
// ---------------------------------------------------------------------------------
- (void) notifyWithDictionary:(NSDictionary *)userInfo
{
	// if alerts not disabled
	if (![[[[AppDelegate sharedInstance] prefs] objectForKey:kPreferences_disableAlerts] intValue] && !gStartupItem) {
		// use Growl if available
		if ([GrowlApplicationBridge isGrowlInstalled]) {
			// save a local copy of userInfo incase the the notification is clicked
			// so we can display a conventional dialog with more options
			[self setAlertInfo:userInfo];
			// do notification
			[GrowlApplicationBridge
				notifyWithTitle:[userInfo objectForKey:GROWL_NOTIFICATION_TITLE]
				description:[userInfo objectForKey:GROWL_NOTIFICATION_DESCRIPTION]
				notificationName:[userInfo objectForKey:GROWL_NOTIFICATION_NAME]
				iconData:nil
				priority:[[userInfo objectForKey:GROWL_NOTIFICATION_PRIORITY] floatValue]
				isSticky:[[userInfo objectForKey:GROWL_NOTIFICATION_STICKY] intValue]
				clickContext:[userInfo objectForKey:GROWL_NOTIFICATION_CLICK_CONTEXT]
				identifier:[userInfo objectForKey:GROWL_NOTIFICATION_IDENTIFIER]
				];
		}
		else {
			// otherwise just do a regular alert
			if ([[userInfo objectForKey:GROWL_NOTIFICATION_NAME] isEqualTo:kTriggerAlert])
				[self alertWithDictionary:userInfo];
		}
	}
}

// ---------------------------------------------------------------------------------
//	• alertWithDictionary
// ---------------------------------------------------------------------------------
- (void) alertWithDictionary:(NSDictionary *)userInfo
{
	// if alerts not disabled
	if (![[[[AppDelegate sharedInstance] prefs] objectForKey:kPreferences_disableAlerts] intValue] && !gStartupItem) {
		NSString *alertStr = [userInfo objectForKey:GROWL_NOTIFICATION_DESCRIPTION];
		NSString *alertAddress = [userInfo objectForKey:kTriggerAlertAddress];
		[[AlertPanelDelegate sharedInstance] showWindow:self];
		[[[AlertPanelDelegate sharedInstance] controller] setAlertText:alertStr];
		[[[AlertPanelDelegate sharedInstance] controller] setAddress:alertAddress];
	}
}

@end

// ---------------------------------------------------------------------------------
//	• 
// ---------------------------------------------------------------------------------
