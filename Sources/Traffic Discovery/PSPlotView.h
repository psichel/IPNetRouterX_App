//
//  PSPlotView.h
//  IPNetMonitorX
//
//  Created by psichel on Mon Mar 18 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.
//
//  Encapsulates drawing a monitor plot from an array of data elements

#import <Cocoa/Cocoa.h>
@class PSPlotEntry;

@interface PSPlotView : NSView
{
    IBOutlet NSTextField *scaleTopR;
    IBOutlet NSTextField *scaleMidR;
    IBOutlet NSTextField *scaleTopT;
    IBOutlet NSTextField *scaleMidT;

    NSMutableArray* data;
    float scaleFactor;
    u_long scaleMax;
    int	shiftCount;
    int plotCount;
    BOOL useLinearScale;
	
	// remember drawing colors
	NSColor* r1;
	NSColor* r2;
	NSColor* r3;
	NSColor* t1;
	NSColor* t2;
	NSColor* t3;
}
- (void)setLinearScale:(BOOL)value;
- (void)updateScale;
- (u_long)scaleMax;
- (int)addEntry:(PSPlotEntry *)entry;
- (int)addEntryBack:(PSPlotEntry *)entry;
- (void)setEntry:(PSPlotEntry *)entry atIndex:(unsigned)index;
@end
