#import <Cocoa/Cocoa.h>

// An address range is presented as a set of CIDR aggregates.
// The address difference "delta" is a sequence of 1s and 0s
// indicating which blocks must be added or subtracted to cover
// the corresponding range.  We use "left" and "right" to mark
// the start and end position of the delta sequence.  "aggregateBlocks"
// remembers where we are in the range or which blocks (1 bits from
// delta) have been added to the base address.  "aggregateLen" is the
// current block size given as a CIDR prefix length (bit position in delta).
typedef struct {
    UInt32 delta;
    UInt32 aggregateBlocks;
    UInt8  aggregateLen;
    UInt8  left;
    UInt8  right;
} RangeT;

@interface SubnetWindowC : NSWindowController
{
    IBOutlet NSTextField* classField;
    IBOutlet NSTextField* hostField;
    IBOutlet NSComboBox* ipAddressCombo;
    IBOutlet NSTextField* maskField;
    IBOutlet NSTextField* networkField;
    IBOutlet NSTextField* prefixLengthField;
    IBOutlet NSStepper* prefixLengthStepper;
    IBOutlet NSStepper* networkStepper;
    IBOutlet NSStepper* hostStepper;
@protected
    BOOL	mPrefixMatch;		// address class matches prefixLenght
	UInt8	mNetworkStep;
    UInt8	mHostStep;
    RangeT	mRange;
}
- (void)windowWillClose:(NSNotification *)aNotification;
- (void)windowDidBecomeKey:(NSNotification *)aNotification;
- (BOOL)setFields:(NSDictionary *)aDictionary;
- (void)update;	// update fields based on new input
- (IBAction)addressChange:(id)sender;
- (IBAction)hostStep:(id)sender;
- (IBAction)networkStep:(id)sender;
- (IBAction)prefixLengthStep:(id)sender;
// history menu
- (void)historyAdd:(id)sender;
- (void)historyAddFavorite:(id)sender;
- (void)historyRemove:(id)sender;
- (void)historyClear:(id)sender;
- (void)historyClearFavorites:(id)sender;
// help
- (IBAction)myHelp:(id)sender;
@end

#define kSubnetName	@"SubnetCalculator"
#define kSubnet_open	@"SubnetCalculator_open"
#define kSubnet_target	@"SubnetCalculator_target"

#define preferences [NSUserDefaults standardUserDefaults]
