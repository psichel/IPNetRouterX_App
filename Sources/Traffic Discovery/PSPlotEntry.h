//
//  PSPlotEntry.h
//  IPNetMonitorX
//
//  Created by psichel on Tue Mar 19 2002.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PSPlotEntry : NSObject <NSCopying, NSCoding> {
    u_long sent;
    u_long received;
    u_long retransmit;
    u_long duplicate;
    u_long sentControl;
    u_long receivedControl;
    u_long sentAverage;
    u_long receivedAverage;
}
- (id)init;
- (void)dealloc;
- (u_long)sent;
- (void)setSent:(u_long)value;
- (u_long)received;
- (void)setReceived:(u_long)value;

- (u_long)retransmit;
- (void)setRetransmit:(u_long)value;
- (u_long)duplicate;
- (void)setDuplicate:(u_long)value;

- (u_long)sentControl;
- (void)setSentControl:(u_long)value;
- (u_long)receivedControl;
- (void)setReceivedControl:(u_long)value;

- (u_long)sentAverage;
- (void)setSentAverage:(u_long)value;
- (u_long)receivedAverage;
- (void)setReceivedAverage:(u_long)value;


- (u_long)maxR;
- (u_long)maxT;
- (NSString *)description;
// <NSCoding>
- (void)encodeWithCoder:(NSCoder *)coder;
- (id)initWithCoder:(NSCoder *)coder;
// <NSCopying>
- (id)copyWithZone:(NSZone *)zone;
@end
