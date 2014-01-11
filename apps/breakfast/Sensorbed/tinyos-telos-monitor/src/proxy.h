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
 * @author Jong Hyun Lim <ljh@cs.jhu.ed>
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
#include "serialsource.h"
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <netdb.h>
#include <fcntl.h>
#include <sys/select.h>
#include "restart.h"

/* Constants */
#define MINPORT 5000
#define TYPESIZE 1
#define NUM_ARGS 4
#define REP_SIZE 4
#define NUM_TYPE 4
#define BUF_SIZE 1024
#define DATA_SIZE 256 
#define SIZE_FIELD 1
#define MACSIZE 9
#define SUCCESS 1
#define FAIL 0
#define UNKNOWN 0
#define ENOSERIAL 3

/* File permission and flags for binary file */
#define FLAGS (O_CREAT | O_TRUNC | O_RDWR)
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
void process_request(int sock, char* s_port, serial_source s_src);

/* Packet definitions */
struct _ackpacket{
	uint8_t type;
	uint8_t error;
}__attribute__((__packed__));
typedef struct _ackpacket AckPacket;

struct _datapacket{
	uint8_t type;
	char mac[8];
	uint32_t rd_cnt;
	uint32_t wr_cnt;
	uint8_t len;
	char data[DATA_SIZE];
}__attribute__((__packed__));
typedef struct _datapacket DataPacket;

#endif
