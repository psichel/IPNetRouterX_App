//
//  IPICMPSocket.m
//  IPNetMonitorX
//
//  Created by psichel on Wed Jun 27 2001.
//  Copyright (c) 2001 Sustainable Softworks. All rights reserved.
//
//  Encapsulate a BSD ICMP Socket
//  receiveFrom can block
//	  assumes client establishes a time out (can use setSO_RCVTIMEO)
//  does not encapsulate threading

#import "IPICMPSocket.h"
#import "AppSupport.h"
#import <sys/uio.h>		// iovec

@implementation IPICMPSocket
//--Setup--
- (id)init {
    int socket;
    socket = OpenRawSocket([NSArray arrayWithObject:@"-icmp"]);
    self = [super initWithSocket:socket];
	mCloseSocket = YES;
    return self;    
}
@end


// ------------------------------------------------
// BSD Descriptor Passing using sendmsg and recvmsg
// ------------------------------------------------
// arguments is an array of command line args (NSStrings)
// specifying the kind of socket we want:
// -icmp, -kev, -routing, -dhcpServer, -dhcpClient, -bpf
const int kFDSize = sizeof(int);
int SendFD( int channel, int fd );
int ReceiveFD( int channel );

int
OpenRawSocket(NSArray* arguments)
{
    int	fd[2] = { -1, -1 };
    NSFileHandle* fp;
    NSString* path;
	BOOL toolExists;
    NSTask* aTask;
    int newSocket;
    
    // create a stream pipe to read fd from our server tool
    if ( socketpair( AF_UNIX, SOCK_STREAM, 0, fd ) == -1 ) {
        NSLog (@"Cannot create a socket pair" );
        return 1;
    }
    fp = [[NSFileHandle alloc] initWithFileDescriptor:fd[1] closeOnDealloc:NO];
    // get path to our server tool
    path = [AppSupport toolPathForName:@"OpenICMP" fileExists:&toolExists];
	if (!toolExists) {
		NSLog(@"Helper tool OpenICMP was not found at path: %@",path);
		[fp release];
		return 2;
	}
    // create a task to run our server tool with our stream pipe
	aTask = [[NSTask alloc] init];
    [aTask setStandardOutput:fp];
    [aTask setArguments:arguments];
    [aTask setLaunchPath:path];
    [aTask launch];
    
    // read the socket
    newSocket = ReceiveFD(fd[0]);
    [aTask release];
	// release the stream pipe
    [fp release];
	Close(fd[0]);
	Close(fd[1]);
    return(newSocket);
}

int
SendFD( int channel, int fd )
{
    char buff[kFDSize];
    struct iovec iov[1];
    struct msghdr msg = {0};
    struct data {
        struct cmsghdr cmsg;
        int fd;
    } data;

    int struct_data_size = sizeof(struct cmsghdr) + sizeof(int);
    memset( &data, 0, sizeof( data ));
    
    iov[0].iov_base = buff;
    iov[0].iov_len = kFDSize;
    
    msg.msg_iov = iov;
    msg.msg_iovlen = 1;
    
    data.cmsg.cmsg_level = SOL_SOCKET;
    data.cmsg.cmsg_type = SCM_RIGHTS;
    data.cmsg.cmsg_len = struct_data_size;
    data.fd = fd;
    msg.msg_control = (caddr_t) &data;
    msg.msg_controllen = struct_data_size;

    // [PAS] interpret negative fd as resultCode and send it in msg buff
    bzero(buff, kFDSize);
    if (fd < 0) {
        data.fd = 0;
        memcpy(buff, &fd, kFDSize);
    }
    
    if ( sendmsg( channel, &msg, 0 ) == -1 ) return 0;
    return 1;
}

int
ReceiveFD( int channel )
{
    char buff[kFDSize];
    int fd = 0;
    struct iovec iov[1];
    struct msghdr msg = {0};
    int resultCode;
    
    struct data {
        struct cmsghdr cmsg;
        int fd;
        char padding[12];
    } data;
    memset( &data, 0, sizeof( data ));
    
    iov[0].iov_base = buff;
    iov[0].iov_len = kFDSize;
    
    msg.msg_iov = iov;
    msg.msg_iovlen = 1;
    
    msg.msg_control = (caddr_t) &data;
    msg.msg_controllen = sizeof( struct data );
    if ( recvmsg( channel, &msg, 0 ) == -1 ) return -1;
    
    fd = data.fd;
    if( (uint32_t) msg.msg_controllen < sizeof( struct cmsghdr ) +
    sizeof( int )) {
        errno = EIO; // bit vague I know...
        return -1;
    }
    // [PAS] if buff is <0 pass back as result code
    memcpy(&resultCode, &buff, kFDSize);
    if (resultCode < 0) fd = resultCode;
    
    return fd;
}
