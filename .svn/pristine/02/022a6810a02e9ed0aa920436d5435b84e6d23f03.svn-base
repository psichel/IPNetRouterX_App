//
//  NameServiceWC.h
//  IPNetRouterX
//
//  Created by psichel on Tue Jan 03 2006.
//  Copyright (c) 2006 Sustainable Softworks. All rights reserved.
//
//  Window controller for configuring UNIX bind BIND

#import <Cocoa/Cocoa.h>
@class NameServiceModel;

@interface NameServiceWC : NSWindowController
{
    IBOutlet NSButton *startButton;
	IBOutlet NSTextField *nameServerState;
	IBOutlet NSTextField *stateDescription;
	IBOutlet NSTableView *localNetworksTableView;
	IBOutlet NSTableView *hostNamesTableView;
	
    IBOutlet NSTextField *statusInfo;
	IBOutlet NSButton *saveButton;
	IBOutlet NSButton *revertButton;
	IBOutlet NSButton *applyButton;
    IBOutlet NSTabView *tabView;
	IBOutlet NSPopUpButton *templateFilePopUp;
    IBOutlet NSTextView *templateView;
	
	NameServiceModel* nameServiceModel;
	NSString* previousTitle;
	NSTimer* refreshTimer;
}
- (NSString *)previousTitle;
- (void)setPreviousTitle:(NSString *)value;

- (IBAction)templateFilePopUp:(id)sender;
- (void)receiveNotification:(NSNotification *)aNotification;
- (IBAction)myHelp:(id)sender;
- (IBAction)showLog:(id)sender;

- (IBAction)startButton:(id)sender;
- (IBAction)saveButton:(id)sender;
- (IBAction)revertButton:(id)sender;
- (IBAction)applyButton:(id)sender;
- (IBAction)resetToDefaultButton:(id)sender;
- (IBAction)fillInTemplateButton:(id)sender;
- (void)refreshTemplate;
- (void)refreshTimer:(id)timer;
//- (IBAction)moveUp:(id)sender;
//- (IBAction)moveDown:(id)sender;
@end
NSString* clean(NSString* inText);

#define kNameService_name	@"NameService"
#define kNameService_open	@"NameService_open"