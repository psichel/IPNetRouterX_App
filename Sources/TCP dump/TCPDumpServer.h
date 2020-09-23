//
//  TCPDumpServer.h
//  IPNetMonitorX
//
//  Created by psichel on Wed Jan 12 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.
//
//  Encapsulates performing tcpdump in a separate thread.
//  We use a Distributed Objects (DO) server design to synchronize
//  with the main AppKit UI thread.
//

#import <Foundation/Foundation.h>
//#import <AppKit/AppKit.h>
#import "PSServer.h"
@class IPHost;

@interface TCPDumpServer : PSServer
{
}

- (void)doTCPDump:(NSString*)interfaceName withOptions:(NSString*)optionStr;
- (void)doTCPFlow:(NSString*)interfaceName withOptions:(NSString*)optionStr;
- (void)outputData:(NSData *)data;
- (void)appendString:(NSString *)inString newLine:(BOOL)newLine;
@end
