//
//  FilterTypes.h
//  IPNetSentryX
//
//  Created by Peter Sichel on Tue Aug 06 2002.
//  Copyright (c) 2002 Sustainable Softworks, Inc. All rights reserved.
//
//	Filter data definitions shared between client and NKE

typedef enum {
    kFilterAny,		// all packets
    kFilterNone,	// no packets
    kFilterDirection,
    kFilterInterface,
	kFilterInclude,
	kFilterSourceMACAddress,
	kFilterDestMACAddress,
    kFilter__1,
    kFilterSourceNet,
    kFilterDestNet,
    kFilterProtocol,
    kFilterIPFragmentOffset,
    kFilterIPOptions,
    kFilterICMPType,
    kFilterICMPCode,
    kFilter__2,
    kFilterTCPHeaderFlags,
    kFilterTCPOptions,
    kFilterSourcePort,
    kFilterDestPort,
    kFilterDataContent,
    kFilterURLKeyword,
    kFilter__3,
    kFilterTimeOfDay,
	kFilterDayOfWeek,
	kFilterDateAndTime,
	kFilterIdleSeconds,
	kFilterParentIdleSeconds,
	kFilterParentMatchCount,
	kFilterParentMatchRate,
	kFilterParentByteCount
} filterProperty;

typedef enum {
    kRelationEqual,
    kRelationNotEqual,
    kRelationIgnoreCase,
	kRelationGreaterOrEqual,
	kRelationLessOrEqual
} filterRelation;

typedef enum {
    kActionLevelNext,
    kActionLevelSkip,
	kActionGroup,
	KActionExitGroup,
    kActionPass,
    kActionDelete,
    kActionReject,
	
    kActionDropConnection,
	kActionKeepAddress,
	kActionKeepInvalid,
	kActionAuthorize,
    kActionTrigger,
	kActionDelay,
	
	kActionRateLimitIn,
	kActionRateLimitOut,
	kActionRouteTo,
	
    kActionLog,
	kActionDontLog,
    kActionAlert,
	kActionEmail,
	kActionURL,
	kActionResetParent,
	kActionAppleScript,
	kActionNotCompleted
} filterActions;

typedef enum {
	kDirectionOutbound,
	kDirectionInbound
} filterDirection;

typedef enum {
	kIncludeTrigger,
	kIncludeAddress,
	kIncludeAuthorize,
	kIncludeInvalid,
	kIncludeState
} filterInclude;

typedef enum {
	kInterfaceInternal,
	kInterfaceExternal
} interfaceExternal;

// rule 0 firewall events
typedef enum {
	kReasonConsistencyCheck,	// internal inconsistency detected
	kReasonShortIPHeader,
	kReasonNotV4,
	kReasonHeaderChecksum,
	kReasonShortTCPHeader,
	kReasonICMPLength,
	kReasonNATActionReject,
	kReasonSourceIPZero,
	kReasonDelayTableFull,
	kReasonConnectionState,
	kReasonOutOfMemory,
	kReasonLast
} logEvent;

