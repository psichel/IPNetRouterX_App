//
//  AirPortConfigurationWindowM.m
//  IPNetRouterX
//
//  Created by Peter Sichel on Mon Dec 29 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.

#import "AirPortConfigurationWindowM.h"
#import "AirPortConfigurationWindowC.h"
#import "PSSharedDictionary.h"
#import "PSSupport.h"

@implementation AirPortConfigurationWindowM

+ (AirPortConfigurationWindowM *)sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[AirPortConfigurationWindowM alloc] init];
	}
	return sharedTask;
}

- (IBAction)showWindow:(id)sender
{
    AirPortConfigurationWindowC *airPortController;
    NSEnumerator* en;
    NSWindow* window;
    // Only one AirPortConfiguration server window
    // check if it already exists, if so bring to front, else create it
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[AirPortConfigurationWindowC class]]) break;
    }
    if (window) {
        [window makeKeyAndOrderFront:sender];
    }
    else {
        // create window controller and make it the windows owner
        airPortController = [AirPortConfigurationWindowC alloc];
        airPortController = [airPortController
            initWithWindowNibName:kAirPortConfigurationName owner:airPortController];
        if (airPortController) {
            [[airPortController window] setFrameUsingName:kAirPortConfigurationName];
            [[airPortController window] makeKeyAndOrderFront:sender];
        }
    }
}

// count number of open windows
+ (int)count
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[AirPortConfigurationWindowC class]]) count += 1;
    }
    return count;
}

// close open windows and return how many we found
- (int)closeAll
{
    NSEnumerator* en;
    NSWindow* window;
    int count = 0;
    // count how many we have so far
    en = [[NSApp windows] objectEnumerator];
    while (window = [en nextObject]) {
        if ([[window delegate] isKindOfClass:[AirPortConfigurationWindowC class]]) {
            count += 1;
            [[PSSharedDictionary sharedInstance] setObject:[NSNumber numberWithInt:count] forKey:@"instanceCount"];
            [window close];
        }
    }
    return count;
}

@end
