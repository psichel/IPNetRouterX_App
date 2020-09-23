//
//  BPFTransmit.h
//  IPNetMonitorX
//
//  Created by Peter Sichel on 8/23/05.
//  Copyright 2005 Sustainable Softworks Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface BPFTransmit : NSObject {
	NSString* bsdName;
	int hwType;
	int bpf_fd;
}

- (id)initWithName:(NSString*)name type:(int)type;
- (NSString*)bsdName;
- (void)setBsdName:(NSString*)value;
- (int)hwType;
- (void)setHwType:(int)value;
- (int)sendData:(u_int8_t*)dp ipOffset:(int)ipOffset ipLen:(int)ipLen
hwDest:(u_int8_t*)hwDest hwDestLen:(int)hwDestLen;
@end
