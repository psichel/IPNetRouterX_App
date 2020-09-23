//
//  Created by Ingvar Nedrebo on Tue Mar 19 2002.
//

#import <Foundation/Foundation.h>

@interface PseudoTTY : NSObject
{
    NSString * name_;
    NSFileHandle * masterFH_;
    NSFileHandle * slaveFH_;
}

-(id)init;
-(NSString *)name;
-(NSFileHandle *)masterFileHandle;
-(NSFileHandle *)slaveFileHandle;

@end
