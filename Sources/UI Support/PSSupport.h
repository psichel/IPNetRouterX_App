//
//  PSSupport.h
//  IPNetMonitorX
//
//  Created by Peter Sichel on Thu Sep 26 2002.
//  Copyright (c) 2002 Sustainable Softworks, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// global system version info obtained during app startup
//extern int gMajorVersion, gMinorVersion, gMinorMinorVersion;


// function declarations
NSString* instanceName(NSString* key, int index);
    // append index to key to form instance name key_index
int instanceCount(Class windowControllerClass);
    // count number of open windows of given type (controller class)

// hide and unhide views backward compatible with 10.2 (setHidden is 10.3 or later)
void hideView(NSView* theView);
void unhideView(NSView* theView);

// open named help anchor in Apple Help Viewer
void openHelpAnchor(NSString* anchor);
// open help file in users default browser
BOOL openHelpFile(NSString* filePath);
