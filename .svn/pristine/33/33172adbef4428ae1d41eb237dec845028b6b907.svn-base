//
// kftConnection.h
// IPNetSentryX
//
// Created by Peter Sichel on Tues Jun 10 2003.
// Copyright (c) 2003 Sustainable Softworks, Inc. All rights reserved.
//
// Kernel Connection Table and support functions
//
#include <sys/types.h>
#include "ipkTypes.h"

#define DEBUG_RATE_LIMITING_1 0
#define DEBUG_RATE_LIMITING_2 0

#define CONVERT_BPS 8

// KFT_connectionEntry defined in ipkTypes.h
/*
// ---------------------------------------------------------------------------
// Connection Entry
// ---------------------------------------------------------------------------
// define connection table entry used to maintain connection state

#define kRttIndexMax 2
struct KFT_connectionInfo {
	u_int32_t ackNumber;
	u_int32_t ackDelta;
	u_int32_t seqNumber;
	struct timeval seqTime;
	u_int32_t rtt_msec[kRttIndexMax+1];	// rtt measurements
	int rttIndex;
	int waitForAck;
	u_int16_t mss;
	u_int16_t windowActual;
	u_int16_t windowApparent;
};
typedef struct KFT_connectionInfo KFT_connectionInfo_t;

struct KFT_connectionEntry {
	KFT_connectionEndpoint_t remote;
	KFT_connectionEndpoint_t local;
	KFT_stat_t	dataIn;
	KFT_stat_t	dataOut;
	u_int32_t	lastTime;
	u_int32_t	flags;
	u_int16_t	dropCount;
	u_int8_t	dupSynCount;		// duplicate sent SYN for failover
	// connection state
	u_int32_t   seqFINLocal;		// seq# to check for last ACK
	u_int32_t   seqFINPeer;
	// bandwidth management
	KFT_connectionInfo_t rInfo;
	KFT_connectionInfo_t sInfo;
//	KFT_seqList_t rSeqList;
//	KFT_seqList_t sSeqList;
	struct timeval callbackKey_tv;
	u_int32_t callbackKeyUnique;	// distinguish similar callback times
	u_int8_t callbackDirection;
	// frame header info used by source aware routing, rate limiting, respondACk
	u_int8_t attachIndex;		// interface where packet arrived from
	u_int8_t rxfhlen;			// rx frame header len
	u_int8_t txfhlen;			// tx frame header len
	u_int8_t rxfh[kFHMaxLen];	// rx frame header
	u_int8_t txfh[kFHMaxLen];	// tx frame header
};
typedef struct KFT_connectionEntry KFT_connectionEntry_t;

// Values for NAT entry Flags
#define kConnectionFlagFINLocal			2		// Seen TCP FIN from local host
#define kConnectionFlagFINPeer			4		// Seen TCP FIN from peer
#define kConnectionFlagClosed			8		// Closed by firewall
#define kConnectionFlagNonSyn			0x80	// Sent more than a Syn
#define kConnectionFlagDelete			0x0100
#define kConnectionFlagUpdate 			0x0200

struct	ipk_connectionUpdate {
	int32_t	length;		// length of message
    int16_t	type;		// message type
    int8_t	version;	// version
	int8_t	flags;		// flag bits
	KFT_connectionEntry_t connectionUpdate[1];	// some number of connection updates
};
typedef struct ipk_connectionUpdate ipk_connectionUpdate_t;
*/

void KFT_connectionStart();
void KFT_connectionStop();
int KFT_connectionAdd(KFT_packetData_t* packet);
int KFT_connectionInclude(KFT_packetData_t* packet);
int KFT_connectionState(KFT_packetData_t* packet);
void KFT_connectionSyn(KFT_packetData_t* packet);
void KFT_sourceAwareActiveOpen(KFT_connectionEntry_t* cEntry);
// rate limit support
KFT_connectionEntry_t* KFT_callbackAction();
int KFT_callbackMoveWindow(KFT_connectionEntry_t* cEntry, int8_t direction);
int KFT_callbackSendACK(KFT_connectionEntry_t* cEntry, int8_t direction);
int KFT_callbackCount();
// age
int KFT_connectionAge(int fromTimer);
int KFT_connectionEntryAge(void * key, void * iter_arg);
int KFT_connectionEntryRemove(KFT_connectionEntry_t* entry);
int KFT_connectionDelete(KFT_connectionEntry_t* entry);
// report
int KFT_connectionReport();
int KFT_connectionEntryReport(void * key, void * iter_arg);
void KFT_connectionSendUpdates();
int KFT_connectionCount();
// traffic discovery
int KFT_trafficReport(void * key, void * iter_arg);
int KFT_cTrafficReport(void * key, void * iter_arg);
void KFT_trafficSendUpdates(int8_t flags);
// AVL
KFT_memStat_t* KFT_connectionMemStat(KFT_memStat_t* record);
int KFT_connectionFree (void * key);
int KFT_callbackFree (void * key);
int KFT_connectionCompare (void * compare_arg, void * a, void * b);
int KFT_callbackCompare (void * compare_arg, void * a, void * b);

/*
Strategy for smooth TCP rate limiting

The rate limit is set from a matching filter rule.  Each connection entry that matches
a rate limit rule records the index of the rate limit rule it matched.

When the connection table is aged each second, we count how many active connections
that sent data match the same rate limit rule and divide the rate limit or bandwidth
by this number of Active connections.  This determines the initial target rate in bytes
per second for each connection that matches a rate limit rule.  [We assume the number
of active connections per second is relatively stable.]

TCP uses a sliding window to control how much data is allowed in flight.

To provide smooth rate control, we need to control when and how much the window moves
to allow more data to be sent.  Notice the receive window has a windowStart and a
windowLimit.  Either or both can move.  The amount we ACK moves the window start.
The advertised window determines the windowLimit.  ACKs are never actually withheld
since we want to give TCP plenty of accurate round trip estimates.
What we need to control is when and how much the windowLimit moves.

Each time an ACK is sent, we adjust the advertised window based on the target
window and next moveWindow time.  We limit the transfer rate for subsequent
data by calculating a new move window time.  The subsequent transferAmount
is the advertised window (prev amount would be ackDelta) plus any previously
transferred bytes that have not yet been counted.

We store the following connection info:

	u_int32_t prevAckNum;	// the last seq number we Acked
	int32_t prevAckWin;		// the advertised window sent with the Ack
	int32_t prevRWin;		// previous actual window size received;
	int32_t uncountedMove;	// ackNum beyond previous window limit, record uncounted move
	struct timeval moveWindow_tv;	// when the receive window should next be moved

When the next ACK is seen, we check it against the moveWindow_tv to see if the
windowLimit can be moved.  If not, we send the remaining window if any up to the
windowLimit and add this connection to the callbackTree to advance the windowLimit
at the appropriate time.
 
Notice we need a way to remove a connection entry from the callback Table if the corresponding
connection table entry is deleted.  Since the connection table is already an AVL tree, we simply
create another AVL tree to index these same entries by callback time plus a unique identifier.
 
 callbackAddEntry()
 callbackRemoveEntry()
 
When the callback timer fires, we remove the first entry in the table, send
an ACK to move the windowLimit by targetWindow, and update the moveWindow_tv.
We then check if the next entry in the callback tree is ready to be processed
and repeat.  If not, we reschedule a BSD timeout for this entry.

Finally, we need to specify a target window size or how much to move the windowLimit each time
it slides.  For a given transfer rate, the amount we move the window is inversely proportional
to how often we'll need to move it. We have chosen moving the window at least 10 times
per second as a reasonable balance between processing overhead and fine grain rate
control.  This implies a targetWindow size of targetBytes/10 causing us to service each
connection about 10 times per second.  This is only an approximate target since the
actual window size must fall between MSS and the window advertised by the actual receiver.
 
 At the low end, a window size of 17 KB (170kbps) might be several seconds worth
 of data on a 33.3k modem.  Allowing this much data in flight would saturate the
 link regardless of any rate control attempted.  Picking a window size that requires
 moving the window 10 times per second leaves room for rate control to work.
 The link can't saturate for longer than 100ms leaving it fairly responsive
 
 At the high end, "WindowSize = Bandwidth * RTT" so we could calculate the target
 WindowSize based on the target rate and measured RTT for each connection, and then
 adjust the advertised window size to match the target while avoiding window shrink
 (advertising a smaller window than was previously promised).  This provides corse
 rate control since the Window Size is only adjusted gradually and also limits
 the amount of data sent in a single burst to help spread out the traffic.
 With "WindowSize = Bandwidth * RTT" we would need to move the window approximately
 every RTT which could be only a few milliseconds on a LAN.
 
 For the common window size of 64 KB, the transfer rate would be 640 KB or 6.4 Mpbs.
 For anything faster than 6.4 Mbps, we'll end up using the actual window size which
 is as close as we can get to moving the window 10 times per second.
 For typical high speed Internet or partitioned 10 Mbps LAN traffic, we'll end up
 reducing the window size modestly and doing 10 window moves/sec.

 At 10 Mbps, we need almost 20 window moves per second (50 ms).
 At 100 Mbps, we need almost 200 window moves per second (5 ms).
 Since we don't want to schedule so many timer callbacks, we check
 the callback tree with each ACK packet processed and do not schedule the
 next timeout for less than 20 ms (50 per second).  At the upper end between
 10-100 Mbps, we might give up a little accuracy for reduced overhead,
 but the practical difference should be small since ACKS will be processed
 every few milliseconds.  At 100 Mbps, a 1500 byte Ethernet frame is about
 0.15 ms.  If every other frames is an ACK, we'll barely miss a beat.
 Since the window size is big enough to exceed the rate limit, we don't
 want to fire early.

The technique above ensures smooth rate limiting in the sense that a connection
will not exceed a target rate.

Since the rate limit is for all connections that match the rate limit rule, we
track intervalBytes at the rate limit rule itself.  If the elapsed fraction of the
rate limit is greater than intervalBytes sent so far, we can make the difference
available to other active connections.  Conversely, if the elapsed fraction 
of the rate limit is less than intervalBytes sent so far (more connections), we
can take the difference away.  We do this by calculating an adjusted rate limit
for each connection.  Notice we don't try to make up lost time for individual
connections but rather try to keep the rate limit consistent.  Instead we
try try to adjust for number of active connections if our initial estimimate
was wrong.  Thus we try to compensate for big errors if the number of active
connections changes dramatically, but don't worry about the small stuff.

Reserving Bandwidth

In addition to limiting bandwidth for a class of traffic, we want to be
able to reserve bandwidth without leaving it unused when it is not needed.
We do this by making the last rate limit rule adjustable based on how
much of their limit any previous rate limit rules consumed.

Each rate limit rule reserves bandwidth for any matching traffic up to
the specified limit.  If more than half the bandwidth limit is used,
the specified limit is subtracted from the rate limit of the last
rate limit rule. If less than half is used, only subtract the amount used.

The last rate limit rule becomes a "catch all" that limits everything else
based on the amount actually used by any previous rules.  Thus previous rate
limit rules effectively reserve bandwidth when needed, but still allow it to
be used by other traffic when not needed.

*/
