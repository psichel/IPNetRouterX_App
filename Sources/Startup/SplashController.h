#import <Cocoa/Cocoa.h>

@interface SplashController : NSObject
{
    IBOutlet id image;
    IBOutlet NSTextField* licenseName;
    IBOutlet NSTextField* licenseNumber;
    IBOutlet NSTextField* licenseOrg;
    IBOutlet NSTextField* version;
    IBOutlet id window;
}
- (void)setLicenseName:(NSString *)value;
- (void)setLicenseOrg:(NSString *)value;
- (void)setLicenseNumber:(NSString *)value;
- (void)setVersion:(NSString *)value;
@end
