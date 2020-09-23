//
//  PSImageString.m
//  IPNetMonitorX
//
//  Created by psichel on Wed Dec 05 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//

#import "PSImageString.h"

@implementation PSImageString
- (id)initWithImage:(NSString *)name {
    if (self = [super init]) {
        wrapper = nil;
        attachment = nil;
        string = nil;
        path=[[NSBundle mainBundle] pathForImageResource:name];
        wrapper=[[[NSFileWrapper alloc] initWithPath:path] autorelease];
        attachment=[[[NSTextAttachment alloc] initWithFileWrapper:wrapper] autorelease];
        string=[[NSAttributedString attributedStringWithAttachment:attachment] retain];        
    }
    return self;
}

- (void)dealloc {
    if (string) [string release];
    [super dealloc];
}

- (NSAttributedString *)string {
    return string;
}
@end
