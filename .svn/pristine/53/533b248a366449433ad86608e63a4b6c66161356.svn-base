//
//  PSServerInterface.h
//  IPNetMonitorX
//
//  Created by psichel on Tuesday Jul 17 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Specify formal protocols for communicating with server threads

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

// Controller to Thread:
@protocol ThreadFromController
//+ (void)connectWithPorts:(NSArray *)portArray;
- (oneway void)startService:(NSString *)inURL fromController:(id)controller withObject:(id)object;
- (int)synchStartService:(NSString *)inURL fromController:(id)controller withObject:(id)object;
@end

// Thread to Controller:
@protocol ControllerFromThread
- (oneway void)receiveDictionary:(NSDictionary *)dictionary;
- (BOOL)didUserAbort;
// test if user pressed abort or other redirection
// note value returned (two way).
@end

// Use these as keys for emulating an NSNotification as a dictionary
// by specifying a notification name (action) and optional object.
// This allows us define a structure for upstream messages:
// message type (action), message content, and sender (object).
extern NSString *PSAction;
extern NSString *PSObject;
// standard Action keys for upstream messages
//extern NSString *PSUpdateParametersNotification;	// default when not specified
extern NSString *PSTestCompleteNotification;
extern NSString *PSServerFinishedNotification;
extern NSString *PSReportErrorNotification;

/*  Design Notes:
The AppKit pretty much requires that we handle asynchronous networking
in a separate thread and synchronize user interface updates with the run
loop of the main thread since AppKit is not re-entrant.
We use a Distributed Objects (DO) server design to synchronize
with the main AppKit UI thread.

Locating networking in a separate thread also enables us to leverage the
BSD kernel facilities for responding to asynchronouse events (select,
signal, socket timeouts, etc.).  The fundamental design issue is how to
divide responsibilities between the main thread and auxilliary networking
threads.

Two alternatives were considered:
(1) We could design simple networking threads like SendUDPThread and
    ReceiveUDPThread which exchange network message objects with the
    main thread.
    
    Advantages:
    - These simple networking primitives are easily re-usuable
      and effectively isolate the system dependent asynchronous networking
      functions (similar to the existing PowerPlant design).

    Disadvantages:
    - The main thread or window controller retains knowledge of the
      underlying network service since it implements the message processing
      logic unless we isolate it in a separate object creating another
      layer of structure.
    - We incure the performance overhead of Distributed Objects for relaying
      messages to the main thread.

(2) Design task specific network servers that run in a separate thread
    and exchange User Interface information with the main thread.
    
    Advantages:
    - Uses thread objects for both asynchronous processing and MVC
      design by putting all networking logic in a separate thread.
    - Can extend the use of DO to remote the User Interface
      via the network, provide alternate user interfaces,
      or faceless background versions.
    - Network send and receive are in the same thread as
      server processing for efficiency and more closely follows
      traditional UNIX networking implementations.
    
    Disadvantages:
    - Each service requires a DO interface to the main thread.
    - Need to encapsulate networking primitives (send and receive)
      separately which we do with our IPHost and IPSocket classes.

We have chosen design (2) for IPNetMonitorX, so we need to define
the DO interfaces for exchanging UI data with the main thread.

To initiate various network tests, we will gather up the corresponding
window parameters and pass them as a URL.  The URL formats are previously
defined for IPNetMonitor under Classic.  This design is simple, efficient,
and easy to remote.  See More on URLs below.

To allow the network server to communicate with its controlling client,
we define a receiveNotification method that takes an NSNotification
object as its parameter.  The userInfo of the notification specifies
a dictionary containing parameter updates or other information.
We define three generic notification types: updateParameters,
serverFinished, and reportError.

To allow the network server to update window parameters
we define an updateParameters method that returns a dictionary of
parameter values.  The dictionary key is a string that names
the field or entity to be updated and the value can be any object.
For NSString objects, we set the named field to the corresponding
stringValue (targetField, statusInfo, etc.).

Since many of our tests generate a series of responses to be displayed
in a table, we can generalize this to a series of table rows or entries.
These table entries are passed as dictionary objects using updateParameters
above. Per MVC design, we want the underlying data to be modelled separately
from the window (view) and notify any observers when data has changed.
In this case we call the window controller directly with updated table
entries and let the window controller handle notification.

We define a serverFinished method to inform the window controller
when the server has completed the requested operation.

We define a reportError method to inform the window controller when
the server encounters an unexpected condition.  The window controller
logs the errorString to the system console and may optionally react
to the condition code.

All of the methods above are declared as "oneway" so the calling
thread continues normal processing without waiting for a response.

Finally we need a way for the window controller to abort a network
operation in progress.  Since our threads communicate using Distributed
Objects, the server thread cannot respond to such a request until
it completes the previous request and is not suspended waiting
for kernel I/O.  Instead we design the server to periodically
poll the window controller (didUserAbort) to see if the user has
pressed Abort. This is consistent with common unix implementations.
If the thread fails to respond, the server still has the option of
killing the thread after an appropriate delay or in response to
Command-period for example.


More On URLs
------------
URL syntax and parsing is described in RFC 1808 and RFC 1738.
The basic syntax components are:

  <scheme>://<net_loc>/<path>;<params>?<query>#<fragment>

  <params> ::= <keyword>=<value> [;<keyword>=<value>]*

  <net_loc> ::= <name>@<host>:<port>
*/
