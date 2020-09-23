/*
 *  Apple80211.h
 *  AirPort
 *
 *  Copyright (c) 2002 Apple Computer, Inc. All rights reserved.
 *
 * The contents of this file are subject to a Confidentiality Agreement (Mutual) (the ‘Agreement’).
 * You may not use this file except in compliance with the Agreement. If you have not already done
 * so, please obtain a copy of the Agreement, execute it, and return it to Apple before using this
 * file.
 *
 * The file distributed under the Agreement is distributed on an ‘AS IS’ basis, WITHOUT WARRANTY OF
 * ANY KIND, EITHER EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES, INCLUDING
 * WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, QUIET
 * ENJOYMENT OR NON-INFRINGEMENT.  Please see the Agreement for the specific language governing
 * rights and limitations under the Agreement. 
 *
 *	Version History:
 *			3.2		Oct 2003	New functions for WPA support
 *			3.1		Jun 2003	Added new functions for AirPort 3.1 (and Panther)
 *			2.1		Sep 2002	Initial release with OS X 10.2 (Jaguar)
 *					Oct 2002	Move WirelessSetWEPKey here (for 802.1X clients)
 */

/*! @header Apple80211.h
 
	Apple80211 is a public subset of the functions contained within
	the Apple80211 private framework.
	
	This file should be installed in:
		/System/Library/PrivateFrameworks/Apple80211.framework/Headers

	and can then be accessed by
		#include <Apple80211/Apple80211.h>

	To use the functions, be sure to add the private framework to your project.
 
 */

#ifndef __APPLE_80211__
#define __APPLE_80211__

#import <CoreFoundation/CoreFoundation.h>

/*!	@typedef	WirelessRef

	@abstract	Opaque connection to the AirPort driver.
*/

typedef UInt32	WirelessRef;

/*!	@enum		WirelessError

	@abstract	Result of call into the AirPort API.

	@constant	errWirelessNoError
					Success. No error occurred.

	@constant	errWirelessNotOnThisPlatform
					AirPort is not supported on the current platform.

	@constant	errWirelessParameterError
					One or more parameters to the called function is bad.

	@constant	errWirelessNotAttached
					WirelessAttach must be called before most functions.

	@constant	errWirelessKernelError
					An internal error occurred.

	@constant	errWirelessIOError
					An error occurred while communicating with an access point.

	@constant	errWirelessNoMemory
					An internal error occurred while attempting to allocate memory.

	@constant	errWirelessTimeout
					No response received from driver after a reasonable amount of time.

	@constant	errWirelessUnexpected
					An unexpected error occurred.

	@constant	errWirelessBadPassword
					The WEP key specified when joining a WEP-protected network is invalid.

	@constant	errWirelessNotActive
					The AirPort driver is not loaded. Not currently returned.

	@constant	errWirelessSNMPError
					An error occurred while parsing an SNMP message.

	@constant	errWirelessPowerOff
					The AirPort card is powered off by the system or the customer.

	@constant	errWirelessDuplicateIBSS
					An attempt to create an IBSS network that already exists.

	@constant	errWirelessBadAuth
					Internal error used to differentiate between open system
					and shared key authentication. Not currently returned.

	@constant	errWirelessNotClientMode
					The attempted operation is not valid when the card is in access point mode.
					
	@constant	errWirelessAPVersionNotRecognized
					The AccessPoint Firmware Version is unrecognized.
*/

typedef enum {
	errWirelessNoError = 0,
	errWirelessNotOnThisPlatform = 0x88001000,
	errWirelessParameterError,
	errWirelessNotAttached,
	errWirelessKernelError,
	errWirelessIOError,
	errWirelessNoMemory,			//0x88001005
	errWirelessTimeout,
	errWirelessUnexpected,
	errWirelessBadPassword,
	errWirelessNotActive,
	errWirelessSNMPError,			//0x8800100A
	errWirelessPowerOff,
	errWirelessDuplicateIBSS,
	errWirelessBadAuth,
	errWirelessNotClientMode,
	errWirelessAPVersionNotRecognized, //0x8800100F
	errWirelessNotAuthenticated,
	errWirelessDirectScanFail,
	errWirelessAssociateTimeout,
	//
	errWirelessLastError			= 0x880010ff	
} WirelessError;

/*!	@enum		WirelessAPICapabilityFlags

	@abstract	Bit field returned in the Wireless Scan structure.

	@constant	kWirelessESS
					Regular infrastructure access point

	@constant	kWirelessIBSS
					IBSS network (computer to computer)

	@constant	kWirelessPrivacy
					Network is using WEP
*/

typedef enum {
    kWirelessESS			= 0x0001,
    kWirelessIBSS			= 0x0002,
    kWirelessPrivacy		= 0x0010,
} WirelessAPICapabilityFlags;

/*!	@struct		WirelessScanInfo

	@field		bssChannelID
					Channel (1-14) in use by the access point.
	
	@field		averageNoiseLevel
					Average noise level as measured by the access point.
	
	@field		signalLevel
					Average signal level as measured by the access point.

	@field		bssMACAddress
					MAC address of the radio card in the access point.

	@field		bssBeaconInterval
					What does this mean?

	@field		bssCapability
					Type of access point. See capability flags above.

	@field		ssidLen
					Length of the name of the network published by the access point.

	@field		ssid
					Name of the wireless network published by the access point.
*/
typedef struct
{
    UInt16		bssChannelID;
    UInt16		averageNoiseLevel;
    UInt16		signalLevel;
    UInt8		bssMACAddress[6];
    UInt16		bssBeaconInterval;
    UInt16		bssCapability;
    UInt16		ssidLen;
    char		ssid[32];
} WirelessScanInfo;
typedef WirelessScanInfo * WirelessScanInfoPtr;

/*!	@enum		WirelessWEPKeyType

	@abstract	Dynamic WEP key types.

	@constant	kWEPKeyTypeDefault
					Default key type.

	@constant	kWEPKeyTypeMulticast
					Used for multi/broad-cast rx.

	@constant	kWEPKeyTypeIndexedTx
					Default (indexed) key for tx.

	@constant	kWEPKeyTypeIndexedRx
					Default (indexed) key for unicast rx.

	@constant	kWEPNumKeyTypes
					Number of valid key types.
*/

typedef enum {
	kWEPKeyTypeDefault = 0,
	kWEPKeyTypeMulticast,
	kWEPKeyTypeIndexedTx,
	kWEPKeyTypeIndexedRx,
	//
	kWEPNumKeyTypes
} WirelessWEPKeyType;

/*!	@enum		WirelessWPAKeyType

	@abstract	Dynamic WPA key types.

	@constant	kWPAKeyTypePSK
					Set the pre-shared key.

	@constant	kWPAKeyTypeSession
					Set the session PMK key.

	@constant	kWPAKeyTypeServer
					Set the server key.

	@constant	kWPAKeyTypeTKIP
					Set the TKIP key directly.

	@constant	kWPAKeyTypeAES
					Set the AES key directly.

	@constant	kWPANumKeyTypes
					Number of valid key types.
*/

typedef enum {
	kWPAKeyTypePSK,
	kWPAKeyTypeSession,
	kWPAKeyTypeServer,
	//
	kWPAKeyTypeTKIP,
	kWPAKeyTypeAES,
	//
	kWPANumKeyTypes
} WirelessWPAKeyType;

/*!	@enum		WirelessLinkStatus

	@abstract	Link Status field in the WirelessInfo structure.

	@constant	kLinkStatusUnavailable
					An error occurred while reading the status.

	@constant	kLinkStatusDisabled
					The AirPort card is disabled.

	@constant	kLinkStatusSearching
					Searching for an initial connection.

	@constant	kLinkStatusIBSS
					Connected to IBSS network.

	@constant	kLinkStatusESS
					Connected to regular network.

	@constant	kLinkStatusOutOfRange
					Temporarily out of range of regular network.

	@constant	kLinkStatusWDS
					Connected to WDS network.
*/

typedef enum
{
	kInfoLinkStatusUnavailable,
	kInfoLinkStatusDisabled,
	kInfoLinkStatusSearching,
	kInfoLinkStatusIBSS,
	kInfoLinkStatusESS,
	kInfoLinkStatusOutOfRange,
	kInfoLinkStatusWDS
} WirelessLinkStatus;

/*!	@enum		WirelessPortType

	@abstract	Port type field in the WirelessInfo structure.

	@constant	kInfoPortTypeClient
					The AirPort card is in normal client mode.

	@constant	kInfoPortTypeSWBS
					The AirPort card is in access point mode.

	@constant	kInfoPortTypeDemo
					The AirPort card is in demo mode (should never occur).

	@constant	kInfoPortTypeIBSS
					The AirPort card is in IBSS (computer to computer) mode.
*/

typedef enum
{
	kInfoPortTypeClient = 1,
	kInfoPortTypeSWBS,
	kInfoPortTypeDemo,
	kInfoPortTypeIBSS
} WirelessPortType;

/*!	@enum		WirelessAssocStatus

	@abstract	Result of last association attempt.

	@constant	kInfoAssocReset
					Internal state indicating the driver is waiting for an association to complete.

	@constant	kInfoAssocConnect
					The last association attempt succeeded.

	@constant	kInfoAssocBadPW
					The last association attempt failed as a result of a bad WEP key.

	@constant	kInfoAssocBadAuth
					Internal state indicating the last association attempt failed
					as a result of bad authentication mode.

	@constant	kInfoAssocUnknown
					An unknown failure occurred.

	@constant	kInfoAssocNotAuthenticated
					Associated but not yet authenticated.
*/

typedef enum
{
	kInfoAssocReset,
	kInfoAssocConnect,
	kInfoAssocBadPW,
	kInfoAssocBadAuth,
	kInfoAssocUnknown,
	kInfoAssocNotAuthenticated
} WirelessAssocStatus;


/*!	@enum		linkStatus

	@abstract	linkStatus field values in WirelessInfo.

	@constant	kLinkStatusUnavailable
					no status available due to h/w or other error.

	@constant	kLinkStatusDisabled
					h/w disabled.

	@constant	kLinkStatusSearching
					attempting to associate.

	@constant	kLinkStatusIBSSConn
					associated with Independent BSS.

	@constant	kLinkStatusESSConn
					associated with Infrastructure network.

	@constant	kLinkStatusOutOfRange
					out of range of previously associated network.

	@constant	kLinkStatusWDSConn
					operating as a WDS (Wireless Distribution Service).

	@constant	kLinkStatusAuthenticating
					Authenticating as part of WPA.
*/

enum
{
	kLinkStatusUnavailable,
	kLinkStatusDisabled,
	kLinkStatusSearching,
	kLinkStatusIBSSConn,
	kLinkStatusESSConn,
	kLinkStatusOutOfRange,
	kLinkStatusWDSConn,
	kLinkStatusAuthenticating
};


/*!	@struct		WirelessInfo

	@field		commQuality
					Normalized signal quality (0 - 100)

	@field		rawQuality
					Raw signal quality (0 - 92)

	@field		avgSignalLevel
					Average signal level (27 - 154)

	@field		avgNoiseLevel
					Average noise level (27 - 154)

	@field		linkStatus
					WirelessLinkStatus

	@field		portType
					WirelessPortType

	@field		lastTxRate
					Speed of last transmission. Note this was not implemented
					on early versions of OS X, and will be zero in that case.

	@field		powerStatus
					Is the card off (0) or on (1)

	@field		lastAssocStatus
					WirelessAssocStatus

	@field		bssID
					MAC address of the wireless card.

	@field		ssid
					Name (zero-terminated) of the currently associated network.
*/

typedef struct {
	UInt16		commQuality;
    UInt16		rawQuality;
    UInt16		avgSignalLevel;
    UInt16		avgNoiseLevel;
    UInt16		linkStatus;
    UInt16		portType;				// 1-normal, 2-SWAP,3-DEMO, 4-IBSS
    UInt16		lastTxRate;				// Most recent transmit data rate
    UInt16		powerStatus;			// 0=off, 1=on
    UInt16		lastAssocStatus;		// last association status
    UInt16		bssID[3];				// BSSID of associated Station
    char		ssid[34];				// Currently associated network
} WirelessInfo;
typedef WirelessInfo * WirelessInfoPtr;

#ifdef __cplusplus
extern "C" {
#endif

/*!	@function	WirelessIsAvailable
	
	@abstract	Quick call to determine if an AirPort card is installed and can be used.
	
	@result		True if a card is installed and configured.
*/

CF_EXPORT Boolean			WirelessIsAvailable();

/*!	@function	WirelessAttach
	
	@abstract	Creates a connection to the AirPort driver.
					This must be called before any Apple80211 functions can be used.
	
	@param		outRef
					Opaque pointer to connection reference.

	@param		unit
					Intended to support multiple cards, must currently be 0.
					
	@result		Error code indicating failure reason or errWirelessNoError if successful.
*/

CF_EXPORT WirelessError		WirelessAttach(
								WirelessRef*	outRef,
								int				unit);

/*!	@function	WirelessDetach
	
	@abstract	Releases the connection to the AirPort driver.
					This should be called after using any Apple80211 functions.
	
	@param		inRef
					Connection reference.

	@result		Error code indicating failure reason or errWirelessNoError if successful.
*/

CF_EXPORT WirelessError		WirelessDetach(
								WirelessRef		inRef);

/*!	@function	WirelessGetInfo
	
	@abstract	Get information about the current state of the AirPort client.
	
	@param		inRef
					Connection reference.

	@param		info
					Pointer to a structure to contain the returned information.
					
	@result		Error code indicating failure reason or errWirelessNoError if successful.
*/

CF_EXPORT WirelessError		WirelessGetInfo(
								WirelessRef		inRef,
								WirelessInfoPtr	info);

/*!	@function	WirelessJoin
	
	@abstract	Associate with the specified wireless network.
				*** DEPRECATED *** Use WirelessAssociate for all new work.
	
	@param		inRef
					Connection reference.

	@param		network
					Name of network to associate with.
					
	@result		Error code indicating failure reason or errWirelessNoError if successful.
*/

CF_EXPORT WirelessError		WirelessJoin(
								WirelessRef		inRef,
								CFStringRef		network);

/*!	@function	WirelessJoinWEP
	
	@abstract	Associate with the specified WEP-protected wireless network.
				*** DEPRECATED *** Use WirelessAssociate for all new work.
				
	@param		inRef
					Connection reference.

	@param		network
					Name of network to associate with.

	@param		password
					Password to use to associate with network. If this password
					is a string, it will be hashed using an Apple proprietary
					method to generate a WEP key. To avoid the hash, enclose
					the 5 or 13 character password with double-quotes, or prefix
					the 10 or 26 hex digits with a dollar sign, and the string
					will be used as is for the WEP key.

	@result		Error code indicating failure reason or errWirelessNoError if successful.
*/

CF_EXPORT WirelessError		WirelessJoinWEP(
								WirelessRef		inRef,
								CFStringRef		network,
								CFStringRef		password);

/*!	@function	WirelessScanSplit
	
	@abstract	Scan for networks, listing IBSS separately.
				*** DEPRECATED *** Use WirelessCreateScanResults for all new work.
	
	@discussion	This function returns two CFArrays that must be released. The array
				contains a number of CFData elements which are simply the binary
				representation of the WirelessScanInfo data structure.
				
				Here is a code snippet illustrating how to retrieve the structure:
				<pre>
				CFIndex count = CFArrayGetCount(networks);
				for (i = 0; i < count; i++)
				{
					CFDataRef		data = (CFDataRef)CFArrayGetValueAtIndex(networks, i);
					WirelessScanInfo* scanInfo = (WirelessScanInfo*)CFDataGetBytePtr(data);
					...
				}
				</pre>

	@param		inRef
					Connection reference.

	@param		networks
					returned list of all Infrastructure networks.

	@param		ibssNetworks
					returned list of all IBSS networks.

	@param		merge
					when true, each network in list appears only once, using the strongest signal.
					
	@result		Error code indicating failure reason or errWirelessNoError if successful.
*/

CF_EXPORT WirelessError		WirelessScanSplit(
								WirelessRef		inRef,
								CFArrayRef*		networks,
								CFArrayRef*		ibssNetworks,
								Boolean			merge);

/*!	@function	WirelessSetWEPKey
	
	@abstract	Set the WEP key dynamically.

	@discussion	This function should be used by 802.1X clients to dynamically set the WEP key.
				This should only happen after the network association has succeeded.
	
	@param		inRef
					Connection reference.

	@param		keyType
					Which key to set (WirelessWEPKeyType).

	@param		keyIndex
					Index (0-3) of WEP key to set.

	@param		keyLen
					Length of the WEP key, must be either 5 or 13 bytes.

	@param		key
					Pointer to the actual WEP key.

	@result		Error code indicating failure reason or errWirelessNoError if successful.
*/

CF_EXPORT WirelessError		WirelessSetWEPKey(
								WirelessRef			inRef,
								WirelessWEPKeyType	keyType,
								UInt32				keyIndex,
								UInt32				keyLen,
								UInt8*				key);

#if 0
#pragma mark >> Added for AirPort 3.1 release
#endif

/*!	@enum		WirelessEncryptType

	@abstract	What type of WEP key to generate.

	@constant	eWirelessEncryptNone
					No encryption key.

	@constant	eWirelessEncrypt40
					40-bit (5 byte) WEP key.

	@constant	eWirelessEncrypt128
					128-bit (13 byte) WEP key.

	@constant	eWirelessWPA
					WPA hashing function.

	@constant	eWirelessAES
					AES hashing function.

	@constant	eWirelessMacRoman
					Add this bit to the type if the passphrase is encoded as MacRoman.
					This is for compatibility purposes only. All new passphrases should be encoded as UTF-8.
*/

typedef enum {
	eWirelessEncryptNone = 0,
	eWirelessEncrypt40,					// 40-bit WEP key
	eWirelessEncrypt128,				// 128-bit WEP key
	eWirelessWPA,						// WPA key
	eWirelessAES,						// AES key
	eWirelessEncryptTypeMask = 0x07ff,
	eWirelessEncryptMacRoman = 0x0800
} WirelessEncryptType;

/*!	@enum		WirelessJoinType

	@abstract	Specify the type of network to join.

	@constant	eJoinInfrastructureOrIBSS
					(Default) Join Infrastructure or IBSS network.

	@constant	eJoinInfrastructure
					Join Infrastructure network only.

	@constant	eJoinIBSS
					Join IBSS network only.

	@constant	eJoin8021X
					Join network protected by 802.1X.

	@constant	eJoinWPA_PSK
					Join network protected by WPA in PSK mode.

	@constant	eJoinWPA_Unspecified
					Join network protected by WPA in EAP mode.
*/

typedef enum {
	eJoinInfrastructureOrIBSS = 0,	// join Infrastructure or IBSS
	eJoinInfrastructure,			// join Infrastructure only
	eJoinIBSS,						// join IBSS only
	eJoinBSSID,						// join the specified BSSID only
	eJoin8021X,						// join 802.1X network
	eJoinWPA_PSK,					// join WPA network
	eJoinWPA_Unspecified 			// join WPA enterprise
} WirelessJoinType;

/*!	@enum		WirelessAPMode

	@abstract	What type of access point to create.

	@constant	eWirelessBG_Compatible
					(Default) 802.11b/g compatible.

	@constant	eWirelessB_Only
					802.11b only.

	@constant	eWirelessG_Only
					802.11g only.
*/

typedef enum {
	eWirelessBG_Compatible = 0,			// 802.11b/g compatible
	eWirelessB_Only,					// 802.11b only
	eWirelessG_Only						// 802.11g only
} WirelessAPMode;

/*!	@function	WirelessAccessPointDisable
	
	@abstract	Disable software access point.
	
	@param		inRef
					Connection reference.

	@result		Error code indicating failure reason or errWirelessNoError if successful.
*/

CF_EXPORT WirelessError		WirelessAccessPointDisable(
								WirelessRef			inRef);

/*!	@function	WirelessAccessPointEnable
	
	@abstract	Enable software access point.
	
	@param		inRef
					Connection reference.

	@param		inSSID
					SSID (32-bytes) of the name of the network to create.

	@param		inChannel
					Channel number to create, 0 for automatic.

	@param		inAPMode
					Which mode (WirelessAPMode) to use -- b-only, g-only, or compatible.

	@param		inKeyType
					Type of encryption key (WirelessEncryptType) to use.

	@param		inPassphrase
					UTF-8 encoded passphrase.

	@param		keyType
					Specify the type of key desired -- 40-bit or 128-bit WEP or WPA.

	@result		Error code indicating failure reason or errWirelessNoError if successful.
*/

CF_EXPORT WirelessError		WirelessAccessPointEnable(
								WirelessRef			inRef,
								CFDataRef			inSSID,
								int					inChannel,
								WirelessAPMode		inAPMode,
								WirelessEncryptType	inKeyType,
								CFStringRef			inPassphrase);

/*!	@function	WirelessAssociate
	
	@abstract	Associate with the specified wireless network.
	
	@param		inRef
					Connection reference.

	@param		joinType
					Specifies the type of network to join.

	@param		network
					Name of network to associate with.
					
	@param		password
					Password to use to associate with network. If this password
					is a string, it will be hashed using an Apple proprietary
					method to generate a WEP key. To avoid the hash, enclose
					the 5 or 13 character password with double-quotes, or prefix
					the 10 or 26 hex digits with a dollar sign, and the string
					will be used as is for the WEP key.

	@result		Error code indicating failure reason or errWirelessNoError if successful.
*/

CF_EXPORT WirelessError		WirelessAssociate(
								WirelessRef			inRef,
								WirelessJoinType	joinType,
								CFDataRef			network,
								CFStringRef			wepKey);

/*!	@function	WirelessCreateEncryptedKey
	
	@abstract	Generate WEP key.
	
	@param		passphrase
					UTF-8 encoded passphrase.

	@param		keyType
					Specify the type of key desired -- 40-bit or 128-bit WEP or WPA.
					
	@result		CFDataRef containing the encrypted key. You must release this.
*/

CF_EXPORT CFDataRef			WirelessCreateEncryptedKey(
								CFStringRef			passphrase,
								WirelessEncryptType	keyType);


/*!	@function	WirelessDirectedScan
	
	@abstract	Look for specified SSID.
	
	@param		inRef
					Connection reference.

	@param		inSSID
					SSID (32-bytes) of the name of the network to look for.

	@param		inMerge
					TRUE to collapse like-named SSID's into a single record.

	@param		outResults
					Array of network info records.

	@result		Error code indicating failure reason or errWirelessNoError if successful.
*/

CF_EXPORT	WirelessError	WirelessDirectedScan(
								WirelessRef		inRef,
								CFArrayRef*		scan,
								Boolean			merge,
								CFStringRef		network );

/*!	@function	WirelessDirectedScan2
	
	@abstract	Look for specified SSID.
				Replaces WirelessDirectedScan, using a CFDataRef for the
				SSID parameter to allow for UTF-8 network names.
	
	@param		inRef
					Connection reference.

	@param		inSSID
					SSID (32-bytes) of the name of the network to look for.

	@param		inMerge
					TRUE to collapse like-named SSID's into a single record.

	@param		outResults
					Array of network info records.

	@result		Error code indicating failure reason or errWirelessNoError if successful.
*/

CF_EXPORT WirelessError		WirelessDirectedScan2(
								WirelessRef		inRef,
								CFDataRef		inSSID,
								Boolean			inMerge,
								CFArrayRef*		outResults);

/*!	@function	WirelessDirectedScan3
	
	@abstract	Look for specified SSID.
				Replaces WirelessDirectedScan2, adding a parameter
				to indicate whether it should return WPA networks.
				
	
	@param		inRef
					Connection reference.

	@param		inSSID
					SSID (32-bytes) of the name of the network to look for.

	@param		inMerge
					TRUE to collapse like-named SSID's into a single record.

	@param		inWantWPA
					TRUE to return networks using WPA.

	@param		outResults
					Array of network info records.

	@result		Error code indicating failure reason or errWirelessNoError if successful.
*/

CF_EXPORT WirelessError		WirelessDirectedScan3(
								WirelessRef		inRef,
								CFDataRef		inSSID,
								Boolean			inMerge,
								Boolean			inWantWPA,
								CFArrayRef*		outResults);

/*!	@function	WirelessIBSSEnable
	
	@abstract	Enable IBSS.
	
	@param		inRef
					Connection reference.

	@param		inSSID
					SSID (32-bytes) of the name of the network to create.

	@param		inChannel
					Channel number to create, 0 for automatic.

	@param		inAPMode
					Which mode (WirelessAPMode) to use -- b-only, g-only, or compatible.

	@param		inKeyType
					Type of encryption key (WirelessEncryptType) to use.

	@param		inPassphrase
					UTF-8 encoded passphrase.

	@param		keyType
					Specify the type of key desired -- 40-bit or 128-bit WEP or WPA.

	@result		Error code indicating failure reason or errWirelessNoError if successful.
*/

CF_EXPORT WirelessError		WirelessIBSSEnable(
								WirelessRef			inRef,
								CFDataRef			inSSID,
								int					inChannel,
								WirelessAPMode		inAPMode,
								WirelessEncryptType	inKeyType,
								CFStringRef			inPassphrase);

#if 0
#pragma mark >> Added for AirPort 3.2 WPA release
#endif

/*!	@function	WirelessCreatePSK
	
	@abstract	Generate pre-shared key.
	
	@param		inPassphrase
					UTF-8 encoded passphrase.
					
	@param		inSSID
					Network name used to create the PSK.
					
	@result		CFDataRef containing the encrypted key. You must release this.
*/

CF_EXPORT CFDataRef			WirelessCreatePSK(
								CFStringRef			inPassphrase,
								CFDataRef			inSSID);

/*!	@function	WirelessDisassociate
	
	@abstract	Disassociate from the current wireless network.
	
	@param		inRef
					Connection reference.

	@result		Error code indicating failure reason or errWirelessNoError if successful.
*/

CF_EXPORT WirelessError		WirelessDisassociate(
								WirelessRef			inRef);

/*!	@function	WirelessGetAssociationInfo
	
	@abstract	Get information about the last associated network.
	
	@discussion Returns a dictionary of information about the current association.
				The dictionary contains the following keys:
				
				<pre>
					wlAssocIBSS;						// CFBoolean
					wlAssocAuthenticationMode;			// CFNumber (kCFNumberSInt16Type)
					wlAssocCipherMode;					// CFNumber (kCFNumberSInt16Type)
					wlAssocSSID;						// CFData	(up to 32 bytes)
				</pre>
						
	@param		inRef
					Connection reference.

	@result		CFDictionaryRef containing information about the last network association. You must release this.
*/

CF_EXPORT CFDictionaryRef	WirelessGetAssociationInfo(
								WirelessRef			inRef);

/*!	@function	WirelessSetWPAKey
	
	@abstract	Set the WPA key dynamically.

	@discussion	This function should be used by 802.1X clients to dynamically set the WPA key.
				This should happen after the network association has succeeded.
	
	@param		inRef
					Connection reference.

	@param		keyType
					Which key to set (WirelessWPAKeyType).

	@param		keyLen
					Length of the WPA key, must be either 16 or 32 bytes (128 or 256 bits).

	@param		key
					Pointer to the actual WPA key.

	@result		Error code indicating failure reason or errWirelessNoError if successful.
*/

CF_EXPORT WirelessError		WirelessSetWPAKey(
								WirelessRef			inRef,
								WirelessWPAKeyType	keyType,
								UInt32				keyLen,
								UInt8*				key);


/*!	@function	WirelessCreateScanResults
	
	@abstract	Scan for networks, listing IBSS separately.
	
	@discussion	This function returns two CFArrays that must be released. The array
				contains a number of CFDictionary elements which contains the following keys:
				
				<pre>
					wlScanChannel;						// CFNumber (kCFNumberCharType)
					wlScanNoise;						// CFNumber	(kCFNumberCharType)
					wlScanSignal;						// CFNumber	(kCFNumberCharType)
					wlScanBeaconInterval;				// CFNumber	(kCFNumberCharType)
					wlScanCapability;					// CFNumber	(kCFNumberCharType)
					wlScanBSSID;						// CFData	(6 bytes)
					wlScanSSID;							// CFData	(up to 32 bytes)
					wlScanIsWPA;						// CFBoolean
					wlScanMulticastCipher;				// CFNumber	(kCFNumberCharType)
					wlScanUnicastCipherArray;			// CFNumber	(kCFNumberCharType)
					wlScanAuthenticationModesArray;		// CFNumber	(kCFNumberCharType)
					wlScanNetworkName;					// CFString
				</pre>
				
	@param		inRef
					Connection reference.

	@param		networks
					returned list of all Infrastructure networks.

	@param		ibssNetworks
					returned list of all IBSS networks.

	@param		merge
					when true, each network in list appears only once, using the strongest signal.
					
	@result		Error code indicating failure reason or errWirelessNoError if successful.
*/

CF_EXPORT WirelessError		WirelessCreateScanResults(
								WirelessRef		inRef,
								CFDataRef		inSSID,
								CFArrayRef*		networks,
								CFArrayRef*		ibssNetworks,
								Boolean			merge) __attribute__((weak_import));

CF_EXPORT const CFStringRef	wlScanChannel __attribute__((weak_import));						// CFNumber (kCFNumberCharType)
CF_EXPORT const CFStringRef	wlScanNoise __attribute__((weak_import));						// CFNumber	(kCFNumberCharType)
CF_EXPORT const CFStringRef	wlScanSignal __attribute__((weak_import));						// CFNumber	(kCFNumberCharType)
CF_EXPORT const CFStringRef	wlScanBeaconInterval __attribute__((weak_import));				// CFNumber	(kCFNumberCharType)
CF_EXPORT const CFStringRef	wlScanCapability __attribute__((weak_import));					// CFNumber	(kCFNumberCharType)
CF_EXPORT const CFStringRef	wlScanBSSID __attribute__((weak_import));						// CFData	(6 bytes)
CF_EXPORT const CFStringRef	wlScanSSID __attribute__((weak_import));							// CFData	(up to 32 bytes)
CF_EXPORT const CFStringRef	wlScanIsWPA __attribute__((weak_import));						// CFBoolean
CF_EXPORT const CFStringRef	wlScanMulticastCipher;				// CFNumber	(kCFNumberCharType)
CF_EXPORT const CFStringRef	wlScanUnicastCipherArray;			// CFNumber	(kCFNumberCharType)
CF_EXPORT const CFStringRef	wlScanAuthenticationModesArray;		// CFNumber	(kCFNumberCharType)
CF_EXPORT const CFStringRef	wlScanNetworkName;					// CFString

// Information returned from GetAssociationInfo

CF_EXPORT const CFStringRef wlAssocIBSS;						// CFBoolean
CF_EXPORT const CFStringRef wlAssocAuthenticationMode;			// CFNumber (kCFNumberSInt16Type)
CF_EXPORT const CFStringRef wlAssocCipherMode;					// CFNumber (kCFNumberSInt16Type)
CF_EXPORT const CFStringRef wlAssocSSID;						// CFData	(up to 32 bytes)
CF_EXPORT const CFStringRef wlAssocKey;							// CFData	(5, 13, or 32 bytes)


/*!	@enum		WirelessCipherTypes

	@abstract	Cipher types returned by WirelessGetAssociationInfo and
				in the dictionary elements returned by WirelessCreateScanResults.

	@constant	WirelessCipher_None
					No cipher mode in use.

	@constant	WirelessCipher_WEP_40
					40-bit (also called 64-bit) WEP.

	@constant	WirelessCipher_TKIP
					TKIP, default for WPA.

	@constant	WirelessCipher_AES_OCB
					AES OCB type.

	@constant	WirelessCipher_AES_CCM
					AES CCM type.

	@constant	WirelessCipher_WEP_104
					104-bit (also called 128-bit) WEP.
*/

typedef enum {
	WirelessCipher_None,		/* None */
	WirelessCipher_WEP_40,		/* WEP (40-bit) */
	WirelessCipher_TKIP,		/* TKIP: default for WPA */
	WirelessCipher_AES_OCB,		/* AES (OCB) */
	WirelessCipher_AES_CCM,		/* AES (CCM) */
	WirelessCipher_WEP_104		/* WEP (104-bit) */
} WirelessCipherTypes;


/*!	@enum		WirelessAuthenticationTypes

	@abstract	Authentication modes returned by WirelessGetAssociationInfo and
				in the dictionary elements returned by WirelessCreateScanResults.

	@constant	WirelessAuth_None
					No authentication mode in use.

	@constant	WirelessAuth_Unspecified
					EAP authentication, default for WPA.

	@constant	WirelessAuth_PSK
					Pre-shared key authentication.

	@constant	WirelessAuth_OpenSystem
					Open system authentication.

	@constant	WirelessAuth_SharedKey
					Shared key authentication.

	@constant	WirelessAuth_CiscoLEAP
					Original-style Cisco LEAP.

	@constant	WirelessAuth_Disabled
					Legacy mode (non-WPA).
*/

typedef enum {
	WirelessAuth_None,			/* None */
	WirelessAuth_Unspecified,	/* Unspecified authentication over 802.1X: default for WPA */
	WirelessAuth_PSK,			/* Pre-shared Key over 802.1X */
	WirelessAuth_OpenSystem,	/* Open system */
	WirelessAuth_SharedKey,		/* Shared key */
	WirelessAuth_CiscoLEAP,		/* Original Cisco LEAP */
	WirelessAuth_Disabled = 255	/* Legacy (i.e., non-WPA) */
} WirelessAuthenticationTypes;

#ifdef __cplusplus
}
#endif

#endif /* __APPLE_80211__ */
