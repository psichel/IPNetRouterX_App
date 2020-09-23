//
//  NSException_Extensions.h
//
//  Created by psichel on Fri Mar 9 2007.
//  Copyright (c) 2007 Sustainable Softworks, Inc. All rights reserved.
//
//	Add print symbolic stack trace to NSException

#import <Foundation/Foundation.h>

@interface NSException (PSExtensions)
- (void)printStackTrace;
@end

