//
//  TDServer.h
//  IPNetRouterX
//
//  Created by psichel on Wed Jan 24 2007.
//  Copyright (c) 2007 Sustainable Softworks. All rights reserved.
//
//  Encapsulates performing Traffic Discovery I/O in a separate thread
//  so we don't block while using NSPropertyListSerialization classes

#import <Foundation/Foundation.h>
#import "PSServer.h"
#import "PSServerInterface.h"
@class TrafficDiscoveryModel;
@class PSURL;

// enable/disable traffic discovery model as a separate thread
#define TD_THREADING 0

@interface TDServer : PSServer
{
	TrafficDiscoveryModel *tdm;
}

@end

// controller to server
#define kTDTrafficUpdate	@"trafficUpdate"
#define kTDTableUpdate		@"tableUpdate"
#define kTDPlotUpdate		@"plotUpdate"
#define kTDShowNow			@"showNow"
#define kTDSave				@"save"
#define kServerTerminate	@"terminate"

// server to controller
#define kUpdateSort			@"updateSort"
