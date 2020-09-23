//
//  Authorization.h
//  IPNetMonitorX
//
//  Created by psichel on Thu Aug 02 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//	Encapsulate using the Authorization Framework to run a tool with privileges.

#import <Foundation/Foundation.h>
#import <Security/Authorization.h>

@interface Authorization : NSObject {
    AuthorizationRef mAuthorizationRef;
	BOOL _authorizationDeclined;
}
+ sharedInstance; // returns a shared instance of the class

// class methods
+ (void)authorizationNotCompleted;
+ (void)reinstall:(NSString *)name;
+ (int)getPID:(NSString *)forProcess;

// instance methods
- (BOOL)doAuthorization:(NSString *)context;
- (BOOL)isAuthenticated;
- (BOOL)authenticate;
- (void)deauthenticate;
- (int)authorize:(NSArray *)filePaths withCommand:(NSString *)operation;
@end
