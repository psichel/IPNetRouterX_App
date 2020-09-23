//
//  Authorization.m
//  IPNetMonitorX
//
//  Created by psichel on Thu Aug 02 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//	Encapsulate using the Authorization Framework to run a tool with privileges.

#import "Authorization.h"
#import "AppSupport.h"
#import <Security/AuthorizationTags.h>
#include <unistd.h>


@implementation Authorization
// returns an instace of itself, creating one if needed
+ sharedInstance {
	static id sharedTask = nil;
	
	if(sharedTask==nil) {
		sharedTask = [[Authorization alloc] init];
	}
	return sharedTask;
}


#pragma mark -- class methods --
// ---------------------------------------------------------------------------------
//	¥ authorizationNotCompleted
// ---------------------------------------------------------------------------------
// Show an alert for Authentication not completed
+ (void)authorizationNotCompleted
{
    NSRunAlertPanel(PS_PRODUCT_NAME,
        @"Authentication was not completed, some features may not be available.",
        @"OK",
        nil,
        nil);
}

// ---------------------------------------------------------------------------------
//	¥ reinstall
// ---------------------------------------------------------------------------------
+ (void)reinstall:(NSString *)name
{
    NSString* userNotice = [NSString stringWithFormat:@"The application appears to be missing one or more components (%@), please re-install.",name];
	NSLog(@"%@ %@",PS_PRODUCT_NAME,userNotice);
	NSRunAlertPanel(PS_PRODUCT_NAME,
        userNotice,
        @"OK",
        nil,
        nil);
    [NSApp terminate:self];
}

//============================================================================
//	+ (int)getPID:(NSString *)forProcess
//============================================================================
// Retrieves the PID (process ID) for the process specified in 
// (NSString *)forProcess.
// The more specific forProcess is the better your accuracy will be, esp. when 
// multiple versions of the process exist. 
//
+ (int)getPID:(NSString *)forProcess {
	FILE* outpipe = NULL;
	NSString *commandOutput = nil;
	NSString *scannerOutput = nil;
	NSScanner *outputScanner = nil;
	NSScanner *intScanner = nil;
	int pid = 0;
	int len = 0;

	// look for "pid-file"
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *filePath = [NSString stringWithFormat:@"/var/run/%@.pid",forProcess]; 
	if ([fm fileExistsAtPath:filePath]) {
		NSString *pidStr = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
		if (pidStr) return [pidStr intValue];
	}	
	
	// look for process command
	[[forProcess retain] autorelease];
	NSString *popenArgs = [[NSString alloc] initWithFormat:@"/bin/ps -axwwopid,command | grep \"%@\"",forProcess];
    outpipe = popen([popenArgs UTF8String],"r");
	[popenArgs release];

	if(!outpipe) {
        NSLog(@"Error opening pipe: %@",forProcess);
        return 0;
    }
	
	NSMutableData* tempData = [[NSMutableData alloc] initWithLength:512];
	NSMutableData* outputData = [NSMutableData data];	
	do {
        [tempData setLength:512];
        len = fread([tempData mutableBytes],1,512,outpipe);
        if( len > 0 ) {
            [tempData setLength:len];
            [outputData appendData:tempData];        
		}
	} while(len==512);    
	[tempData release];

	pclose(outpipe);
	
	commandOutput = [[NSString alloc] initWithData:outputData encoding:NSASCIIStringEncoding];    
	if( [commandOutput length] > 0 ) {
		outputScanner = [NSScanner scannerWithString:commandOutput];
		[commandOutput release];
		
		[outputScanner setCharactersToBeSkipped:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		[outputScanner scanUpToString:forProcess intoString:&scannerOutput];
		if( [scannerOutput rangeOfString:@"grep"].length != 0 ) {
			return 0;
		}
		intScanner = [NSScanner scannerWithString:scannerOutput];
		[intScanner scanInt:&pid];
		
		if( pid ) {
			return pid;
		}
		else {
			return 0;
		}
	}
	else {
		[commandOutput release];
		return 0;
	}
}

#pragma mark -- instance methods --
- init
{
    if (self = [super init]) {
        mAuthorizationRef = NULL;
		_authorizationDeclined = NO;
    }
    return self;
}
- (void)dealloc
{
    [self deauthenticate];    
    [super dealloc];
}

// ---------------------------------------------------------------------------------
//	¥ doAuthorization
// ---------------------------------------------------------------------------------
- (BOOL)doAuthorization:(NSString *)context
{
    BOOL returnValue = NO;
    int answer = NSAlertDefaultReturn;
    
    // check if we are aleady authorized
	sync();
    if ([[Authorization sharedInstance] isAuthenticated]) return YES;
    // otherwise prompt user for authorization
	if (!_authorizationDeclined) do {
		if (context) {
			answer = NSRunAlertPanel([NSString stringWithFormat:@"%@ First Run",PS_PRODUCT_NAME],
				context,
				//@"You must have Administrator privileges to complete the installation process.",
				//@"You must have Administrator privileges to complete the installation process.  Press Help for more information.",
				@"OK",
				@"Cancel",
				@"Help");
		}
		if (answer == NSAlertDefaultReturn) {
			returnValue = [[Authorization sharedInstance] authenticate];
		}
		else if (answer == NSAlertAlternateReturn) {
			_authorizationDeclined = YES;
			[Authorization authorizationNotCompleted];
		}
		else if (answer == NSAlertOtherReturn) {		// show help information
			NSString *filePath;
			NSURL *fileURL;
			NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];		
			if ((filePath = [thisBundle pathForResource:@"AuthenticationHelp" ofType:@"html" inDirectory:PS_HELP_DIRECTORY]))
			if ((fileURL = [NSURL fileURLWithPath:filePath])) [[NSWorkspace sharedWorkspace] openURL:fileURL];
			[NSThread  sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval)1.0]];
		}
	} while (answer == NSAlertOtherReturn);
    return returnValue;
}

//=====================
- (BOOL)isAuthenticated
//=====================
// Determine if user is authenticated to execute as root
{
    AuthorizationRights rights;
    AuthorizationFlags flags;
    AuthorizationItem items[1];
    BOOL authorized;
    OSStatus err;
    NSString* path;
    
    // create and initialize AuthorizationRef if needed
    if(mAuthorizationRef==NULL)
    {
        rights.count=0;
        rights.items = NULL;
        
        flags = kAuthorizationFlagDefaults;
    
        err = AuthorizationCreate(&rights, kAuthorizationEmptyEnvironment,
            flags, &mAuthorizationRef);
    }
    
    // Check if we have the right to execute our tool as root
    // Use one authorization item for each tool or privilege we need.
    path = [AppSupport bundleToolPath:@"Authorize"];
    items[0].name = kAuthorizationRightExecute;
    items[0].value = (char *)[path fileSystemRepresentation];
    items[0].valueLength = strlen([path fileSystemRepresentation]);
    items[0].flags = 0;

    rights.count=1;
    rights.items = items;
    
    flags = kAuthorizationFlagExtendRights;
    
    // Since we have specified kAuthorizationFlagExtendRights and
    // have not specified kAuthorizationFlagInteractionAllowed,
    // this will return failure if not currently authorized
    err = AuthorizationCopyRights(mAuthorizationRef, &rights,
            kAuthorizationEmptyEnvironment, flags, NULL);

    authorized = (errAuthorizationSuccess==err);
    return authorized;
}

//====================
- (void)deauthenticate
//====================
// invalidate the users AuthorizationRef if any
{
    if (mAuthorizationRef)
    {
        //dispose of any rights our AuthorizationRef has acquired, and null it out
        //so we get a new one next time we need one.
        AuthorizationFree(mAuthorizationRef, kAuthorizationFlagDestroyRights);
        mAuthorizationRef = NULL;
    }
}


//==================
- (BOOL)authenticate
//==================
// Try to authenticate user if needed.
// Return YES if the user is or becomes authenticated.
// May request user password.
{
    AuthorizationRights rights;
    AuthorizationFlags flags;
    AuthorizationItem items[1];
    OSStatus err;
    NSString* path;
    
    path = [AppSupport bundleToolPath:@"Authorize"];
    items[0].name = kAuthorizationRightExecute;
    items[0].value = (char *)[path fileSystemRepresentation];
    items[0].valueLength = strlen([path fileSystemRepresentation]);
    items[0].flags = 0;

    rights.count=1;
    rights.items = items;
    
    flags = kAuthorizationFlagInteractionAllowed 
                | kAuthorizationFlagExtendRights;        
    // Since we have specified kAuthorizationFlagExtendRights and
    // kAuthorizationFlagInteractionAllowed, this may request
    // the user to enter their admin password
    err = AuthorizationCopyRights(mAuthorizationRef, &rights,
            kAuthorizationEmptyEnvironment, flags, NULL);

    return (errAuthorizationSuccess==err);
}


- (int)authorize:(NSArray *)filePaths withCommand:(NSString *)operation
    // execute our Authroize tool with privileges to set file privileges
    // operation will be "-authorize", "-unauthorize", or "-kextauthorize"
	// returns 0 for success or OSError
{
    char* args[64];
    FILE* iopipe;
    //char buf[255];
    NSString* toolPath;
    int i, j;
    int count;
    int returnValue = 0;

//NSLog(@"authorize with command: %@", operation);
//NSLog(@"%@",[filePaths description]);    
    do {
        if ((filePaths == nil) || ([filePaths count] > 62)) {
            returnValue = 1;
            break;
        }
        [filePaths retain];
        toolPath = [AppSupport bundleToolPath:@"Authorize"];
        // setup arguments
		j = 0;
        args[j++] = (char *)[operation UTF8String];	// operation requested
        count = [filePaths count];
        for (i=0; i<count; i++) {
            NS_DURING
				args[j++] = (char *)[[filePaths objectAtIndex:i] fileSystemRepresentation];
			NS_HANDLER
				NSLog(@"Character conversion exception while trying to authorize file path: %@",[filePaths objectAtIndex:i]);
			NS_ENDHANDLER
        }
        args[j++] = NULL;
        returnValue = AuthorizationExecuteWithPrivileges(mAuthorizationRef,
            [toolPath fileSystemRepresentation], 0, args, &iopipe);
        [filePaths release];
    } while (false);
    return returnValue;
}

@end
