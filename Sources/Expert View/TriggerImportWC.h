/* TriggerImportWC */

#import <Cocoa/Cocoa.h>

@interface TriggerImportWC : NSWindowController
{
    IBOutlet NSPopUpButton *triggerDurationPopUp;
    IBOutlet NSTextField *triggeredByField;
    IBOutlet NSPopUpButton *triggerTypePopUp;
	IBOutlet NSTextField *statusInfo;
}
- (IBAction)import:(id)sender;
- (IBAction)export:(id)sender;
- (IBAction)cancel:(id)sender;

- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo;
- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode  contextInfo:(void  *)contextInfo;
@end


#define kTriggerImportName	@"TriggerImport"
#define kTriggerImport_filePath @"TriggerImport_filePath"
