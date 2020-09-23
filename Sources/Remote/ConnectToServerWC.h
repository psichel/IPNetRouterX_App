/* ConnectToServerWC */

#import <Cocoa/Cocoa.h>

@interface ConnectToServerWC : NSWindowController
{
    IBOutlet NSSecureTextField *password;
    IBOutlet NSTextField *server;
    IBOutlet NSTextField *userName;
}
- (IBAction)Cancel:(id)sender;
- (IBAction)Connect:(id)sender;
@end

#define kConnectToServer_name	@"ConnectToServer"