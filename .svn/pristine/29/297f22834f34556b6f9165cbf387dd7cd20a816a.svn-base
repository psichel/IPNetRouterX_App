//
//  TrafficDiscoveryWC.h
//  IPNetRouterX
//
//  Created by psichel on Tue Feb 28 2006.
//  Copyright (c) 2006 Sustainable Softworks. All rights reserved.
//
//  Window controller for viewing service and device traffic data

@class TrafficDiscoveryState;
@class TrafficDiscoveryModel;
@class PSPlotView;
@class TDEntry;
#import <Cocoa/Cocoa.h>

@interface TrafficDiscoveryWC : NSWindowController
{
	IBOutlet NSTextField *dateField;
    IBOutlet NSPopUpButton *intervalPopUp;
	IBOutlet NSButton *stepReverse;
	IBOutlet NSButton *stepGo;
    IBOutlet NSButton *stepForward;
    IBOutlet NSTableView *tableView;
	IBOutlet NSTextField *numberField;
    IBOutlet NSButton *trafficDiscoveryOn;
    IBOutlet NSPopUpButton *viewByPopUp;
	IBOutlet NSButton *showNowButton;
	IBOutlet PSPlotView *bytePlotView;
	IBOutlet NSPopUpButton *plotType;
	IBOutlet NSButton *deviceButton;
	IBOutlet NSButton *serviceButton;
	IBOutlet NSButton *netflowButton;
	
	TrafficDiscoveryState* trafficDiscoveryState;
	TrafficDiscoveryModel* trafficDiscoveryModel;
	BOOL nowPlaying;
	BOOL showNow;
}
// Actions
- (void)receiveNotification:(NSNotification *)aNotification;
- (void)receiveDictionary:(NSDictionary *)dictionary;
- (void)checkSort;
- (void)movePlot:(int)direction;
- (void)reloadPlot;
- (BOOL)showNow;
- (void)setShowNow:(BOOL)value;
// Delegate
- (int)viewBy;
- (NSString *)sortBy;
- (int)interval;
- (NSCalendarDate *)showDate;
- (NSString *)dayGroupKey;
- (void)loadPlotEntry:(TDEntry *)tdEntry;

// IB Actions
- (IBAction)intervalPopUp:(id)sender;
- (IBAction)stepReverse:(id)sender;
- (IBAction)stepGo:(id)sender;
- (IBAction)stepForward:(id)sender;
- (IBAction)showNowButton:(id)sender;
- (IBAction)trafficDiscoveryOn:(id)sender;
- (IBAction)viewByPopUp:(id)sender;
- (IBAction)dateField:(id)sender;
- (IBAction)plotType:(id)sender;
- (void)doubleAction:(id)sender;
- (IBAction)deviceButton:(id)sender;
- (IBAction)serviceButton:(id)sender;
- (IBAction)netflowButton:(id)sender;

- (void)moveLeft:(id)sender;
- (void)moveRight:(id)sender;
- (void)copy:(id)sender;
- (IBAction)myHelp:(id)sender;

// tableView delegate
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;
- (void)tableView:(NSTableView *)inTableView didClickTableColumn:(NSTableColumn *)tableColumn;
@end

#define kTrafficDiscovery_name	@"TrafficDiscovery"
#define kTrafficDiscovery_open	@"TrafficDiscovery_open"
#define kTrafficDiscovery_plotType	@"TrafficDiscovery_plotType"
#define kTrafficDiscovery_viewBy	@"TrafficDiscovery_viewBy"
#define kTrafficDiscovery_interval	@"TrafficDiscovery_interval"

#define kShowNow		0
#define kShowRecorded	1

#define kPlotBytesOfTotal	0
#define kPlotBytes			1
#define kPlotPercent		2
