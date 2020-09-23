#import <Cocoa/Cocoa.h>
@class BasicSetupWC;
@class ExpertViewWC;
@class TriggerImportWC;
#import "AddressScanWindowC.h"
#import "LogWindowC.h"
#import "LookupWindowC.h"
#import "SubnetWindowC.h"
#import "TCPDumpWindowC.h"

@interface MenuDispatch : NSObject
{
	AddressScanWindowC *mAddressScanWindowC;
	LogWindowC *mLogWindowC;
	LookupWindowC *mLookupWindowC;
	SubnetWindowC *mSubnetWindowC;
}
+ (MenuDispatch *)sharedInstance;
// Validation
- (BOOL)validateMenuItem:(NSMenuItem*)anItem;
// Preferences
- (IBAction)preferencesShowWindow:(id)sender;
- (unsigned)preferencesCount;
- (int)preferencesCloseAll;
// Diagnostic
- (IBAction)diagnosticShowWindow:(id)sender;
- (unsigned)diagnosticCount;
- (int)diagnosticCloseAll;
// Registration
- (IBAction)registrationShowWindow:(id)sender;
// airPortConfiguration
- (IBAction)airPortConfigurationShowWindow:(id)sender;
- (int)airPortConfigurationCloseAll;

// *** Remote ***
- (IBAction)connectToLocalServer:(id)sender;
- (IBAction)disconnect:(id)sender;
// connectToServer
- (IBAction)connectToServerShowWindow:(id)sender;
- (int)connectToServerCloseAll;
// administrators
- (IBAction)administratorsShowWindow:(id)sender;
- (int)administratorsCloseAll;

#if IPNetRouter
// DHCP Server
- (IBAction)dhcpServerShowWindow:(id)sender;
- (int)dhcpServerCount;
- (int)dhcpServerCloseAll;
// DHCP Log Window
- (IBAction)dhcpLogShowWindow:(id)sender;
- (unsigned)dhcpLogCount;
- (int)dhcpLogCloseAll;
// NAT View
- (IBAction)natViewShowWindow:(id)sender;
- (unsigned)natViewCount;
- (int)natViewCloseAll;
// Name Service
- (IBAction)nameServiceShowWindow:(id)sender;
- (int)nameServiceCloseAll;
// Route
- (IBAction)routeShowWindow:(id)sender;
- (unsigned)routeCount;
- (int)routeCloseAll;
// AlternateRoute
- (IBAction)alternateRouteShowWindow:(id)sender;
- (unsigned)alternateRouteCount;
- (int)alternateRouteCloseAll;
#endif
// Traffic Discovery
- (IBAction)trafficDiscoveryShowWindow:(id)sender;
- (int)trafficDiscoveryCloseAll;
// Basic Setup
- (IBAction)basicSetupShowWindow:(id)sender;
- (BasicSetupWC*)basicSetupMakeWindowController:(id)sender;
- (int)basicSetupCloseAll;
// Expert View
- (IBAction)expertViewShowWindow:(id)sender;
- (ExpertViewWC*)expertViewMakeWindowController:(id)sender;
- (int)expertViewCloseAll;
// Trigger Import
- (IBAction)triggerImportShowWindow:(id)sender;
- (int)triggerImportCloseAll;
// Sentry Log
- (IBAction)sentryLogShowWindow:(id)sender;
- (unsigned)sentryLogCount;
- (int)sentryLogCloseAll;

// Address Scan
- (IBAction)addressScanShowWindow:(id)sender;
- (int)addressScanCloseAll;
- (AddressScanWindowC *)addressScanWindowC;

// Log
- (IBAction)logShowWindow:(id)sender;
- (int)logCloseAll;
- (LogWindowC *)logWindowC;
// Lookup
- (IBAction)lookupShowWindow:(id)sender;
- (int)lookupCloseAll;
- (LookupWindowC *)lookupWindowC;
// Subnet Calculator
- (IBAction)subnetShowWindow:(id)sender;
- (int)subnetCloseAll;
- (SubnetWindowC *)subnetWindowC;
// TCP Dump
- (IBAction)tcpDumpShowWindow:(id)sender;
- (int)tcpDumpCloseAll;

@end
