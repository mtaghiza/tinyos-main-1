/*
 * Copyright (c) 2012 Johns Hopkins University.
 * All rights reserved.
 * 
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written
 * agreement is hereby granted, provided that the above copyright
 * notice, the (updated) modification history and the author appear in
 * all copies of this source code.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS  `AS IS'
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED  TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR  PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR  CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, LOSS OF USE,  DATA,
 * OR PROFITS) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR  OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 * */

/*
 * @author Jong Hyun Lim <ljh@cs.jhu.edu>
 * @author Doug Carlson <carlson@cs.jhu.edu>
 * - Added hard-coded telos MAC prefix
 * 
 * @version $Revision$ $Date$
 * 
 */

#ifndef PROXY_H 
#define PROXY_H 

#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <string.h>
#include <sys/socket.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <linux/if.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <netdb.h>
#include <fcntl.h>
#include <sys/select.h>
#include <ctype.h>
#include "restart.h"
#include <termios.h>

/* Constants */
#define TYPESIZE 1
#define NUM_ARGS 4
#define REP_SIZE 4
#define TOS_MAX 135
#define MACSIZE 9
#define SUCCESS 1
#define FAIL 0

/* for distinguishing telos from bacon motes */
#define TELOS_MAC_PREFIX "M4"
#define TELOS_MAC_PREFIX_LEN 2

/* File permission and flags for serial and file */
#define FLAGS (O_CREAT | O_TRUNC | O_RDWR)
#define SFLAGS (O_RDWR | O_NOCTTY | O_NONBLOCK)
#define PERMS (S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH) 

/* Request from server to local */
enum{
	DATA = 0,
	REPRO = 1, 
	ERASE = 2,
	RESET = 3
};

/* Function definitions */
int connect_to_server(char* serv_info, uint16_t port_num);
int process_request(int main_sock, int stream_sock, char* s_port);

/* Packet definitions */
struct _ackpacket{
	uint8_t type;
	uint8_t error;
}__attribute__((__packed__));
typedef struct _ackpacket AckPacket;

struct _datapacket{
	uint8_t type;
	char mac[8];
}__attribute__((__packed__));
typedef struct _datapacket DataPacket;

#ifndef REPROGRAM_ATTEMPT_LIMIT
#define REPROGRAM_ATTEMPT_LIMIT 10
#endif

#endif
