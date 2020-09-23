//
//  FilterStyles.m
//  IPNetSentryX
//
//  Created by Peter Sichel on 10/14/05.
//  Copyright 2005 Sustainable Softworks. All rights reserved.
//

#import "FilterStyles.h"


@implementation FilterStyles

+ (FilterStyles *)sharedInstance
{
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[FilterStyles alloc] init];
	}
	return sharedTask;
}

- (id)init
{
    NSString *path;
    if (self = [super init]) {
        path=[[NSBundle mainBundle] pathForResource:@"FilterStyles" ofType:@"plist"];
        stylesDictionary = [[NSDictionary dictionaryWithContentsOfFile:path] retain];
        if (!stylesDictionary) {
			NSBeep();
			NSLog(@"FilterStyles could not find path for resource FilterStyles");
		}
    }
    return self;
}
- (void)dealloc
{
    [stylesDictionary release];
    [super dealloc];
}

- (NSDictionary *)stylesDictionary { return stylesDictionary; }

@end
