//
//  Created by Ingvar Nedrebo on Tue Mar 19 2002.
//

#import "PseudoTTY.h"
#import <util.h>

@implementation PseudoTTY

-(id)init
{
    if (self = [super init])
    {
        int masterfd, slavefd;
        char devname[64];
        if (openpty(&masterfd, &slavefd, devname, NULL, NULL) == -1)
        {
            [NSException raise:@"OpenPtyErrorException"
                        format:@"%s", strerror(errno)];
        }
        name_ = [[NSString alloc] initWithUTF8String:devname];
        slaveFH_ = [[NSFileHandle alloc] initWithFileDescriptor:slavefd];
        masterFH_ = [[NSFileHandle alloc] initWithFileDescriptor:masterfd
                                                  closeOnDealloc:YES];
    }
    return self;
}

-(NSString *)name
{
    return name_;
}

-(NSFileHandle *)masterFileHandle
{
    return masterFH_;
}

-(NSFileHandle *)slaveFileHandle
{
    return slaveFH_;
}


-(void)dealloc
{
    [name_ release];
    [slaveFH_ release];
    [masterFH_ release];
	[super dealloc];
}

@end
