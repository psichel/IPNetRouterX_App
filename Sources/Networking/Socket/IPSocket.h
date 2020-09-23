//
//  IPSocket.h
//  IPNetMonitorX
//
//  Created by psichel on Wed Jun 27 2001.
//  Copyright (c) 2001-02 Sustainable Softworks. All rights reserved.
//
//  Base class for encapsulating a BSD Socket

#import <Foundation/Foundation.h>
#import "unp.h"

// Global
extern NSString *PSAbortFD;


@interface IPSocket : NSObject <NSCopying, NSCoding> {
    int	mSocket;	// BSD socket fd
    int	mAbortFD[2];
	BOOL mCloseSocket;  // socket was opened during init so needs close
}
- (id)initWithSocket:(int)socket;
- (void)dealloc;
- (int)socket;		// return the socket or error we got
- (int)abortFD;		// return other end of abort pipe
- (BOOL)setIP_TTL:(int)value;
- (BOOL)setIP_HDRINCL:(int)value;
- (BOOL)setSO_RCVTIMEO:(time_value_t*)timeValue;
- (BOOL)setSO_TIMESTAMP:(int)value;
- (int)setSO:(int)option param:(void *)param size:(unsigned)size;
- (int)getSO:(int)option param:(void *)param size:(socklen_t *)size;
- (BOOL)setRST;
- (BOOL)setRST:(int)socket;
- (int)waitUntilReadableTimeOut:(NSTimeInterval)seconds;
// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder;
- (id)initWithCoder:(NSCoder *)coder;
// <NSCopying>
- (id)copyWithZone:(NSZone *)zone;
@end


// Forward function declarations
int		ReadableTimeOut(int fd, NSTimeInterval seconds);
int		Socket(int family, int type, int protocol);
