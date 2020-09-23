//
//  DiagnosticWC.h
//  IPNetRouterX
//
//  Created by psichel on Fri Dec 8 2006.
//  Copyright (c) 2006 Sustainable Softworks. All rights reserved.
//
//  Window controller for viewing NKE memory diagnostic

#import <Cocoa/Cocoa.h>
#import "DiagnosticModel.h"

@interface DiagnosticWC : NSWindowController
{
    IBOutlet NSTableView *memoryUseTableView;
    IBOutlet NSButton *reportMemoryUse;
	
	DiagnosticModel *diagnosticModel;
}
- (void)receiveNotification:(NSNotification *)aNotification;
- (IBAction)reportMemoryUse:(id)sender;
- (IBAction)myHelp:(id)sender;
@end

#define kDiagnosticName		@"Diagnostic"
#define kDiagnostic_open	@"Diagnostic_open"

