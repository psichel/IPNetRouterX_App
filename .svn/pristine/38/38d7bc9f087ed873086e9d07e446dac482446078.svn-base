#include "unp.h"
Sigfunc *
Signal(int signo, Sigfunc *func)
{
    struct sigaction act, oact;
    
    act.sa_handler = func;
    sigemptyset(&act.sa_mask);
    act.sa_flags = 0;
    if (signo == SIGALRM) {
#ifdef SA_INTERRUPT
        act.sa_flags |= SA_INTERRUPT;		// SunOS 4.x
#endif
    } else {
#ifdef SA_RESTART
        act.sa_flags |= SA_RESTART;			// SVR4, 4.4BSD
#endif
    }
    if (sigaction(signo, &act, &oact) < 0)
        return (SIG_ERR);
    return (oact.sa_handler);
}

// Error checking wrappers
// Restart interrupted system calls in generic case
// ---------------------------------------------------------------------------------
//	¥ Close
// ---------------------------------------------------------------------------------
int Close(int fd)
{
	int result;
	do {
		result = close(fd);
	} while ((result < 0) && (errno == EINTR));
	return result;
}

// ---------------------------------------------------------------------------------
//	¥ Read
// ---------------------------------------------------------------------------------
ssize_t	 Read(int fd, void *buf, size_t size)
{
	int result;
	do {
		result = read(fd, buf, size);
	} while ((result < 0) && (errno == EINTR));
	return result;
}

// ---------------------------------------------------------------------------------
//	¥ Write
// ---------------------------------------------------------------------------------
ssize_t	 Write(int fd, const void *buf , size_t size)
{
	int result;
	do {
		result = write(fd, buf, size);
	} while ((result < 0) && (errno == EINTR));
	return result;
}

// ---------------------------------------------------------------------------------
//	¥ Select
// ---------------------------------------------------------------------------------
int	Select(int maxfd, fd_set *rset, fd_set *wset, fd_set *except, struct timeval *tvp)
{
	int result;
	do {
		result = select(maxfd, rset, wset, except, tvp);
	} while ((result < 0) && (errno == EINTR));
	return result;
}
