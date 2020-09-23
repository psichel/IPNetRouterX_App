//
//  NKEController.h
//  IPNetSentryX
//
//  Created by psichel on 2007-10-22.
//  Copyright (c) 2007 Sustainable Softworks. All rights reserved.
//
//  Encapsulates connecting to IPNetSentry_NKE

#import <Foundation/Foundation.h>
#import "ipkTypes.h"

@class IPUDPSocket;
@class PsClient;

@interface NKEController : NSObject
{
	BOOL			mConnected;
    IPUDPSocket* 	mIPKSocket;
	PsClient*		mUDPClient;
}
+ (NKEController *)sharedInstance;
- (int)connectToNKEFrom:(id)receiveTarget;
- (int)disconnect;
- (int)sentryAttach:(KFT_interfaceEntry_t *)kftInterfaceEntry;
- (int)sentryDetach:(KFT_interfaceEntry_t *)kftInterfaceEntry;

- (int)setMessageMask:(u_int32_t)messageMask;
- (int)getMessageMask;
- (int)setFlags:(u_int32_t)flags;
- (int)clearFlags:(u_int32_t)flags;

- (BOOL)isConnected;
- (int)setOption:(int)command param:(void *)param size:(unsigned)size;
- (int)getOption:(int)command param:(void *)param size:(unsigned *)size;
- (void)receiveDictionary:(NSDictionary *)dictionary;
// observers
- (void)addObserver:(id)target withSelector:(SEL)method;
- (void)removeObserver:(id)target;
- (BOOL)updateParameter:(NSString *)name withObject:(id)anObject;
@end
