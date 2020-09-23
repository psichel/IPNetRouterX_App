//
//  Scripting.m
//  IPNetRouterX
//
//  Created by Peter Sichel on 8/9/06.
//  Copyright 2006 Sustainable Softworks. All rights reserved.
//

#import "Scripting.h"
#import "my.h"


@implementation NSApplication (Scripting)
#pragma mark -- IPNetRouter Suite --
// ip forwarding
- (NSNumber *)ipForwarding
{
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	myLog(@"Scripting - ipForwarding");
	return [sentryState ipForwarding];

}
- (void)setIpForwarding:(NSNumber *)value
{
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	[sentryState setIpForwarding:value];
	myLog(@"Scripting - setIpForwarding=%@",value);
}

// IPNetRouterOn
- (NSNumber *)firewallOn
{
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	myLog(@"Scripting - firewallOn");
	return [sentryState firewallOn];

}
- (void)setFirewallOn:(NSNumber *)value
{
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	[sentryState setFirewallOn:value];
	myLog(@"Scripting - setFirewallOn=%@",value);
}

// interface table
- (NSMutableArray *)interfaces
{
	myLog(@"Scripting - interfaces");
	return [[InterfaceTable sharedInstance] interfaceArray];
}
- (void)setInterfaceEntries:(NSMutableArray *)value
{
	InterfaceTable* table = [InterfaceTable sharedInstance];
	[table setInterfaceArray:value];
	myLog(@"Scripting - setInterfaceEntries");
}

// port map table
- (NSMutableArray *)portMaps
{
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	myLog(@"Scripting - portMaps");
	return [[sentryState portMapTable] portMapArray];
}

// trigger table
- (NSMutableArray *)triggers
{
	SentryState* sentryState = [[SentryModel sharedInstance] sentryState];
	myLog(@"Scripting - triggers");
	return [[sentryState triggerTable] triggerArray];
}

// ---------------------------------------------------------------------------------
//	• indicesOfObjectsByEvaluatingObjectSpecifier
// ---------------------------------------------------------------------------------
// evaluate object specifiers
- (NSArray *)indicesOfObjectsByEvaluatingObjectSpecifier:(NSScriptObjectSpecifier *)specifier
{
	NSArray* returnValue = nil;
	NSString* uniqueID = nil;
	// don't care about interfaces since walking table is fast enough
	if ([[specifier key] isEqualTo:@"portMaps"]) {
		uniqueID = [(NSUniqueIDSpecifier *)specifier uniqueID];
		// extract elements of key (address, port, protocol)
		// build matching entry
		// return array index of entry get_index_by_key()
	}
	else if ([[specifier key] isEqualTo:@"triggers"]) {
		uniqueID = [(NSUniqueIDSpecifier *)specifier uniqueID];
		// extract elements of key (address, endOffset, type)
		// build matching entry
		// return array index of entry get_index_by_key()

	}
	return returnValue;
}

@end
