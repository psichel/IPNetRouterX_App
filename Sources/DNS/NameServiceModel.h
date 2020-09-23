//
//  NameServiceModel.h
//  IPNetRouterX
//
//  Created by Peter Sichel on 1/6/06.
//  Copyright 2006 Sustainable Softworks. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString* NameServiceNotification;


@interface NameServiceModel : NSObject {
	NSDictionary *templateDefault;
	NSDictionary *templateActive;
	NSMutableDictionary *templateEdit;	// display and edit in text view

	NSString* runNamedPath;
	NSTask* nameServerTask;
	// state model (kept in nameServiceDictionary in SentryState)
	//nameServiceOn
	//localCachingOn
	//templateSaved
	
}
+ (NameServiceModel *) sharedInstance;
- (void)receiveNotification:(NSNotification *)aNotification;

// get/set (working)
- (int)namedIsRunning;
- (void)serverState;

- (NSDictionary *)templateDefault;
- (void)setTemplateDefault:(NSDictionary *)value;
- (NSDictionary *)templateActive;
- (void)setTemplateActive:(NSDictionary *)value;
- (NSMutableDictionary *)templateEdit;
- (void)setTemplateEdit:(NSDictionary *)value;
- (NSString *)runNamedPath;
// get/set saved state
- (NSNumber *)nameServiceOn;
- (void)setNameServiceOn:(NSNumber *)value;

- (NSMutableDictionary *)localCachingOn;
- (void)setLocalCachingOn:(NSMutableDictionary *)value;
- (BOOL)nameServerForNetwork:(NSString *)network;

- (NSString *)zoneNameForNetwork:(NSString *)network;
- (void)setZoneName:(NSString *)zoneName forNetwork:(NSString *)network;

- (NSMutableDictionary *)localHostNames;
- (void)setLocalHostNames:(NSMutableDictionary *)value;
// update templates
- (void)doTemplate_named_conf;
- (void)doTemplate_named_cache;
- (void)doTemplate_zone:(NSString *)zone;
- (NSArray *)internals;
- (NSArray *)enabledInternals;
- (NSArray *)externals;
// actions
- (void)nameServiceSave;
- (void)nameServiceRestore;
- (void)nameServiceApply;

// observer interface
- (void)addObserver:(id)target withSelector:(SEL)method;
- (void)removeObserver:(id)target;
// Notify listeners when state changes
- (BOOL)updateParameter:(NSString *)name withObject:(id)anObject;

@end

#define SS_nameServiceOn	@"nameServiceOn"
#define SS_localCachingOn	@"localCachingOn"
#define SS_localHostNames	@"localHostNames"
#define SS_zoneNames		@"zoneNames"
#define SS_templateSaved	@"templateSaved"

#define kDNS_named_conf		@"named.conf"
#define kDNS_named_cache	@"named.cache"
#define kDNS_localhost_zone	@"localhost.zone"
#define kDNS_localhost_rev	@"localhost.rev"
#define kDNS_lan_zone		@"lan.zone"
#define kDNS_lan_rev		@"lan.rev"

// byte swapping for DNS PTR records
#define swap32(x) \
    ((uint32_t)((((uint32_t)(x) & 0xff000000) >> 24) | \
                (((uint32_t)(x) & 0x00ff0000) >>  8) | \
                (((uint32_t)(x) & 0x0000ff00) <<  8) | \
                (((uint32_t)(x) & 0x000000ff) << 24)))
