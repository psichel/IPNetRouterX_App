#import <Cocoa/Cocoa.h>#import "AlertPanelController.h"@interface AlertPanelDelegate : NSObject{	AlertPanelController* mAlertPanelController;}+ (AlertPanelDelegate *)sharedInstance;- (IBAction)showWindow:(id)sender;- (unsigned)count;- (int)closeAll;- (AlertPanelController *)controller;@end