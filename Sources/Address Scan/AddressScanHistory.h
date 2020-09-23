//
//  AddressScanHistory.h
//  IPNetMonitorX
//
//  Created by psichel on Thu Sep 27 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PSHistory.h"

@interface AddressScanHistory : PSHistory {
}
+ sharedInstance;	// returns a shared instance of the class
@end
