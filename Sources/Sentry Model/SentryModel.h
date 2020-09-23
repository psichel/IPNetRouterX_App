//
//  SentryModel.h
//  IPNetSentryX
//
//  Created by Peter Sichel on Thu May 01 2003.
//  Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
//  Encapsulate IPNetSentryX/IPNetRouterX model actions as part of MVC design pattern.
//
//  SentryDocument displays the current model and interprets user input to change model state.
//  SentryState maintains the model state and notifies observers when it changes.
//  SentryModel observes state changes and performs the corresponding model action.

#import <Foundation/Foundation.h>
#import "SentryState.h"
@class InterfaceTable;
@class TriggerEntry;
#import "ipkTypes.h"
#import PS_TNKE_INCLUDE
#import "kftGlobal.h"
@class SentryLogger;
@class ExpertViewWC;

@interface SentryModel : NSObject {	
	SentryState* sentryState;
	BOOL pending;

	SentryLogger* logger;
    ExpertViewWC* windowController;
	NSDocument* document;	// associated with window controller
}

+ (SentryModel *)sharedInstance;
// Accessors
- (SentryState *)sentryState;
- (void)setSentryState:(SentryState *)value;
- (InterfaceTable *)interfaceTable;
- (id)windowController;
- (void)setWindowController:(id)value;
- (void)updateChangeCount:(NSDocumentChangeType)change;
// Actions
- (void)receiveNotification:(NSNotification *)aNotification;
- (void)downloadTriggerEntry:(TriggerEntry *)entry;
- (void)enableIpForwarding:(NSNumber *)value;
- (void)enableAutomaticFailover:(NSNumber *)value;
- (void)enableLoadBalance:(NSNumber *)value;
- (void)enableSourceAwareRouting:(NSNumber *)value;
- (void)enablePortMapLogging:(NSNumber *)value;
- (void)enableUnregisteredOnly:(NSNumber *)value;
- (void)enableBlockIPv6:(NSNumber *)value;
- (void)enableTrafficDiscovery:(NSNumber *)value;
- (void)disableCommandQ:(NSNumber *)value;
- (void)enableTriggerDuration:(NSNumber *)value;
// table download
- (void)downloadInterfaceTable;
#if IPNetRouter
- (void)downloadPortMapTable;	// SentryTest
- (void)updatePortMapTable:(id)object;
- (void)uploadNatTable;
#endif
@end
// test support
void logAttachTable(attach_t* table);
int PROJECT_modifyReadyPacket(KFT_packetData_t* packet);


// Action notifications that are separate from state changes
// Example: an interface or port map entry has changed and should be sent to NKE
//#define SA_interfaceTable			@"SA_interfaceTable"
//#define SA_portMapTable				@"SA_portMapTable"

#define SA_apply					@"SA_apply"
#define SA_showActive				@"SA_showActive"
#define SA_testButton				@"SA_testButton"
#define SA_triggerDelete			@"SA_triggerDelete"

#define SA_attach					@"SA_attach"
#define SA_detach					@"SA_detach"

