//
//  RouteSupport.m
//  IPNetRouterX
//
//  Created by psichel on Wed Mar 05 2002.
//  Copyright (c) 2002 Sustainable Softworks. All rights reserved.
//
//  Support routines for dealing with Routing Sockets

#import "RouteSupport.h"

// include defnitions from Stevens UNP page 453 and 454
/*
 * Round up 'a' to next multiple of 'size'
 */
#define ROUNDUP(a, size) (((a) & ((size)-1)) ? (1 + ((a) | ((size)-1))) : (a))

/*
 * Step to next socket address structure;
 * if sa_len is 0, assume it is sizeof(u_long).
 */
#define NEXT_SA(ap)     ap = (struct sockaddr *) \
        ((caddr_t) ap + (ap->sa_len ? ROUNDUP(ap->sa_len, sizeof (u_long)) : \
                                                                        sizeof(u_long)))


// include support routines from Stevens UNP page 453 and 454

// build an array of pointers to socket address structures returned in an RTM_GET message
void get_rtaddrs(int addrs, struct sockaddr *sa, struct sockaddr **rti_info)
{
	int             i;

	for (i = 0; i < RTAX_MAX; i++) {
		if (addrs & (1 << i)) {
			rti_info[i] = sa;
			NEXT_SA(sa);
		} else
			rti_info[i] = NULL;
	}
}

// return presentation string for mask value in a generic socket address structure
char *sock_masktop(struct sockaddr *sa, socklen_t salen)
{
	static char		str[INET6_ADDRSTRLEN];
	char	*ptr = &sa->sa_data[2];

	if (sa->sa_len == 0)
		return("0.0.0.0");
	else if (sa->sa_len == 5)
		snprintf(str, sizeof(str), "%d.0.0.0", *ptr);
	else if (sa->sa_len == 6)
		snprintf(str, sizeof(str), "%d.%d.0.0", *ptr, *(ptr+1));
	else if (sa->sa_len == 7)
		snprintf(str, sizeof(str), "%d.%d.%d.0", *ptr, *(ptr+1), *(ptr+2));
	else if (sa->sa_len == 8)
		snprintf(str, sizeof(str), "%d.%d.%d.%d",
				 *ptr, *(ptr+1), *(ptr+2), *(ptr+3));
	else
		snprintf(str, sizeof(str), "(unknown mask, len = %d, family = %d)",
				 sa->sa_len, sa->sa_family);
	return(str);
}
// my IPv4 version
u_int32_t sock_mask(struct sockaddr *sa, socklen_t salen)
{
	int returnValue = 0;
	char	*ptr = &sa->sa_data[2];

	if (sa->sa_len == 0) returnValue = 0;
	else if (sa->sa_len == 5) returnValue = (*ptr << 24);
	else if (sa->sa_len == 6) {
		returnValue = (*ptr << 24) | (*(ptr+1) << 16);
	}
	else if (sa->sa_len == 7) {
		returnValue = (*ptr << 24) | (*(ptr+1) << 16) | (*(ptr+2) << 8);
	}
	else if (sa->sa_len == 8) {
		returnValue = (*ptr << 24) | (*(ptr+1) << 16) | (*(ptr+2) << 8) | (*(ptr+3));
	}
	return returnValue;
}

char *sock_ntop_host(const struct sockaddr *sa, socklen_t salen) { 
    static char str[128];                /* Unix domain is largest */ 

        switch (sa->sa_family) { 
        case AF_INET: { 
                struct sockaddr_in        *sin = (struct sockaddr_in *) sa; 

                if (inet_ntop(AF_INET, &sin->sin_addr, str, sizeof(str)) == NULL) 
                        return(NULL); 
                return(str); 
        } 
        default: 
                snprintf(str, sizeof(str), "sock_ntop_host: unknown AF_xxx: %d, len %d", 
                                 (int)sa->sa_family, (int)salen); 
                return(str); 
        } 
    return (NULL); 
} 
// my IPv4 version
u_int32_t sock_host(const struct sockaddr *sa, socklen_t salen) { 
	u_int32_t returnValue = 0;
	if (sa->sa_family == AF_INET) { 
		struct sockaddr_in *sin = (struct sockaddr_in *)sa;
		returnValue = ntohl(sin->sin_addr.s_addr);
	} 
    return returnValue; 
}
