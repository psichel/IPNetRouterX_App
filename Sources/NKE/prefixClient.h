// use pre-compiled headers to speed up compilation
#ifdef __OBJC__
#import <Cocoa/Cocoa.h>
#endif

// Compile time switch to build as NKE or client code
#define IPK_NKE 0
// use panther style mbufs for testing in client
#define TIGER 0
// build as GUI app versus HelperTool
#define BUILD_AS_HELPER_TOOL 0

// Compile time switch to build as IPNetRouter versus IPNetSentry
#define IPNetRouter 1
#define PS_PRODUCT_NAME @"IPNetRouterX"
#define PS_STARTUP_ITEM_NAME @"IPNetRouterX_startup"
#define PS_BUNDLE_ID @"com.sustworks.IPNetRouterX"
#define PS_HELP_DIRECTORY @"IPNetRouterX Help/html"
#define PS_HELP_DIRECTORY2 @"IPNetRouterX Help"

#define PS_KEY_NAME @"IPNetRouterX_key"
//#define PS_UPGRADE_KEY_NAME @"IPNetRouterX Upgrade_key"
#define PS_KEY_FILENAME @"IPNetRouterKey"
//#define PS_UPGRADE_KEY_FILENAME @"IPNetRouterUpgradeKey"

#define PS_KEXT_NAME @"IPNetRouter_NKE.kext"
#define PS_NKE_NAME @"IPNetRouter_NKE"
#define PS_NKE_INCLUDE "IPNetRouter_NKE.h"
// Tiger NKE
#define PS_TKEXT_NAME @"IPNetRouter_TNKE.kext"
#define PS_TNKE_NAME @"IPNetRouter_TNKE"
#define PS_TNKE_INCLUDE "IPNetRouter_TNKE.h"

// name prefix for global symbol names
#define PROJECT com_sustworks_ipnr
