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

#include "proxy.h"

fd_set mask;
serial_source s_src;
uint32_t wr_cnt = 0;
uint32_t rd_cnt = 0;
char MAC[MACSIZE];

static void print_usage(char* program_name)
{
	fprintf(stderr, "Usage: %s [IP address or DNS] [serial port] [MAC]\n", program_name);
	fprintf(stderr, "\tIP address or DNS\n");
	fprintf(stderr, "\tserial port\tSerial port of box. (ex: /dev/ttyUSB0)\n"); 
	fprintf(stderr, "\tMAC\t\tMAC address of the mote. (ex: M4AN1DBR)\n"); 
}

int check_socket_read(int ret_val)
{
	if ( ret_val < 0 ) {
		perror("request_from_server, recv()");
		return EAGAIN;
	}
	if ( ret_val == 0 ) {
		perror("server disconnected");
		return ECONNRESET;
	}
	return SUCCESS;
}

void clear_socket(int sock)
{
	FD_CLR(sock, &mask); 
	r_close(sock); 
}

void clear_serial(int serial_fd, serial_source src)
{
	FD_CLR(serial_fd, &mask); 
	close_serial_source(src); 
}

void reset_counter()
{
	wr_cnt = 0;
	rd_cnt = 0;
}

void stderr_msg(serial_source_msg problem)
{
  static char *msgs[] = {
    "unknown_packet_type",
    "ack_timeout"	,
    "sync"	,
    "too_long"	,
    "too_short"	,
    "bad_sync"	,
    "bad_crc"	,
    "closed"	,
    "no_memory"	,
    "unix_error"
  };
  fprintf(stderr, "Note: %s\n", msgs[problem]);
}


/* 					connect_to_server
 * Description: 
 * 		return socket number that has a TCP connection established 
 * 		otherwise, return -1 (error)
 * Parameters: 
 * 		serv_info, IP address or DNS name 
 * 		p_num, port number 
 * Return: 
 * 		-1, any error on establishing connection to server 
 * 		> 0, socket number 
 */
int connect_to_server(char* serv_info, uint16_t port_num)
{
	int sock = -1;
	struct sockaddr_in serv_addr;
	struct hostent* p_h_ent;
	struct hostent h_ent;
	in_addr_t ip_addr;
	char* c;

	/* Remove new line or carriage return */
	c = strchr(serv_info, '\n');
	if ( c ) *c = '\0';
	c = strchr(serv_info, '\r');
	if ( c ) *c = '\0';
#ifdef DEBUG
	fprintf(stderr, "Trying to connect...\nServer Address: %s, Port: %u\n", serv_info, port_num);
#endif 
	if( (sock = socket(PF_INET, SOCK_STREAM, 0)) < 0){
		fprintf(stderr, "[connect_to_server] socket error\n");
		return -1;
	}
	bzero(&serv_addr, sizeof(serv_addr));
	serv_addr.sin_family = AF_INET;
	if( (ip_addr = inet_addr(serv_info)) == INADDR_NONE){
		/* If user entered DNS address, instead of IP address */
		p_h_ent = gethostbyname(serv_info);
		if(p_h_ent == NULL){
			fprintf(stderr, "[connect_to_server] gethostbyname() error\n");
			return -1;
		}
		memcpy(&h_ent, p_h_ent, sizeof(h_ent));
		memcpy(&ip_addr, h_ent.h_addr, sizeof(in_addr_t));
	}
	serv_addr.sin_addr.s_addr = ip_addr;
	serv_addr.sin_port = htons(port_num);
	if(connect(sock, (struct sockaddr*)&serv_addr, sizeof(struct sockaddr_in)) == -1){
		fprintf(stderr, "[connect_to_server] connect error\n");
		return -1;
	}
#ifdef DEBUG
	fprintf(stderr, "Connection Established...\n");
#endif 
	return sock;
}

static void send_ack_to_server(int sock, uint8_t ret)
{
	AckPacket* ack = (AckPacket*)malloc(sizeof(AckPacket));
	ack->type = 1; 
	ack->error = ret;
	if(send(sock, ack, sizeof(AckPacket), 0) < 0){
#ifdef DEBUG
	fprintf(stderr, "Error in sending ack to server, type: 1, error:%u\n", ret);
#endif
	}
	else{
#ifdef DEBUG
	fprintf(stderr, "Successful in sending ack to server, type: 1, error:%u\n", ret);
#endif
	}
	free(ack);
}

/* 
 *  			send_data_to_serial
 *
 * Description: if server sends data for mote to command or send, proxy forward it 
 * 				to mote 
 * Parameters: 
 * 		sock, open socket with server 
 * 		s_port, fully-qualified path name of serial dev, e.g. /dev/ttyUSB0
 * 		src, opened file descriptor and buffer for serial device 
 */
static uint8_t send_data_to_serial(int sock, char* s_port, serial_source s_src)
{
	uint8_t pkt_len = 0;
	uint8_t read_bytes = 0;
	uint8_t* p_data = NULL;
	
	read_bytes = recv(sock, &pkt_len, SIZE_FIELD, 0);
	if(read_bytes != SIZE_FIELD){
		fprintf(stderr, "error in reading size field of data packet\n");
		return FAIL;
	}
	p_data = (uint8_t*)malloc(pkt_len);
	read_bytes = recv(sock, p_data, pkt_len, 0);
	if( read_bytes <= 0 ){
		fprintf(stderr, "error in reading data field of data packet\n");
		return FAIL;
	}
	/* send data to opened serial */
	if( write_serial_packet(s_src, p_data, pkt_len) != 0){
		fprintf(stderr, "error in writing data to serial\n");
		free(p_data);
		return FAIL;
	}
	wr_cnt++;
	free(p_data);
	return SUCCESS;
}

/* 
 *  			reprogram_mote 
 *
 * Description: reprogram mote with ihex file delivered from server 
 * Parameters: 
 * 		sock, open socket with server 
 * 		s_port, fully-qualified path name of serial dev, e.g. /dev/ttyUSB0
 */
static uint8_t reprogram_mote(int sock, char* s_port)
{
	uint32_t size = 0, ptr;
	uint32_t temp_size = 0;
	uint32_t bytes = 0;
	char filename[25];
	int fd;
	pid_t childpid;
	char* ihex;

	bytes = recv(sock, &size, REP_SIZE, 0);
	if(bytes != REP_SIZE){
		fprintf(stderr, "error in reading size field\n");
		return FAIL;
	}
	temp_size = ntohl(size);
	size = temp_size;
	ihex = (char*)malloc(size);
	bytes = 0; ptr = 0;
	while( temp_size > 0 && (bytes = recv(sock,ihex+ptr,temp_size,0)) > 0 ){
		temp_size = temp_size - bytes;
		ptr = ptr + bytes;
	}
	sprintf(filename, "main.ihex.out-%d", sock);
	fd = r_open3(filename, FLAGS, PERMS);
	if (fd == -1) {
		fprintf(stderr, "error in creating file\n");	
		return FAIL;
	}
	if ( (bytes = r_write(fd, ihex, size)) == -1){
		fprintf(stderr, "error in creating file\n");	
		return FAIL;
	}
	fprintf(stderr, "written success %d %d\n", bytes, size);
	if(r_close(fd) == -1){
		fprintf(stderr, "error in closing file\n");	
		return FAIL;
	}
	free(ihex);
	close_serial_source(s_src);
	/* fork extra process to handle request */
	childpid = fork();
	if (childpid == -1) {
		fprintf(stderr, "error in forking child\n");
		return FAIL;
	}
	/* child code */
	if (childpid == 0) {
		execl("/usr/bin/cppbsl", "cppbsl", "-b", "-p", filename, "-c", s_port, NULL);
		fprintf(stderr, "error in executing child process\n");
		perror("why?");
		return FAIL;
	}
	/* parent code */
	if (childpid != r_wait(NULL)) {
		fprintf(stderr, "Parent failed to wait\n");
		return FAIL;
	}
	/* Delete file */
	/* if(remove(filename) != 0){
		fprintf(stderr, "error in deleting ihex file\n");
	} */
	s_src = open_serial_source(s_port, 115200, 0, stderr_msg);
	if (!s_src) {
		fprintf(stderr, "Failed to open serial port\n");
		exit(1);
	}
	reset_counter();
	return SUCCESS;
}

/* 
 *  			 erase_mote
 *
 * Description: erase mote with child process executed 
 * Parameters: 
 * 		s_port, fully-qualified path name of serial dev, e.g. /dev/ttyUSB0
 */
static uint8_t erase_mote(char* s_port)
{
	pid_t childpid;

	close_serial_source(s_src);
	/* fork extra process to handle request */
	childpid = fork();
	if (childpid == -1) {
		fprintf(stderr, "error in forking child\n");
		return FAIL;
	}
	/* child code */
	if (childpid == 0) {
		execl("/usr/bin/cppbsl", "cppbsl", "--telosb", "-c", s_port, "-e",  NULL);
		fprintf(stderr, "error in executing child process\n");
		return FAIL;
	}
	/* parent code */
	if (childpid != r_wait(NULL)) {
		fprintf(stderr, "Parent failed to wait\n");
		return FAIL;
	}
	s_src = open_serial_source(s_port, 115200, 0, stderr_msg);
	if (!s_src) {
		fprintf(stderr, "Failed to open serial port\n");
		exit(1);
	}
	fprintf(stderr, "erase mote\n");
	reset_counter();
	return SUCCESS;
}

/* 
 *  			 reset_mote 
 *
 * Description: reset mote with child process executed 
 * Parameters: 
 * 		s_port, fully-qualified path name of serial dev, e.g. /dev/ttyUSB0
 */
static uint8_t reset_mote(char* s_port)
{
	pid_t childpid;

	close_serial_source(s_src);
	/* fork extra process to handle request */
	childpid = fork();
	if (childpid == -1) {
		fprintf(stderr, "error in forking child\n");
		return FAIL;
	}
	/* child code */
	if (childpid == 0) {
		execl("/usr/bin/cppbsl", "cppbsl", "--telosb", "-c", s_port, "-r",  NULL);
		fprintf(stderr, "error in executing child process\n");
		return FAIL;
	}
	/* parent code */
	if (childpid != r_wait(NULL)) {
		fprintf(stderr, "Parent failed to wait\n");
		return FAIL;
	}
	s_src = open_serial_source(s_port, 115200, 0, stderr_msg);
	if (!s_src) {
		fprintf(stderr, "Failed to open serial port\n");
		exit(1);
	}
	reset_counter();
	return SUCCESS;
}

/* 
 *  			 request_from_server
 *
 * Description: when request from server arrives, parse the request by type
 * Parameters: 
 * 		sock, opened socket with server 
 * 		s_port, fully-qualified path name of serial dev, e.g. /dev/ttyUSB0
 * 		src, opened file descriptor and buffer for serial device 
 */
static int request_from_server(int sock, char* s_port, serial_source s_src)
{
	int bytes_read, ret = 0;
	uint8_t type = 0;

	bytes_read = recv(sock, &type, TYPESIZE, 0);
	if( (ret = check_socket_read(bytes_read)) != SUCCESS){
		return ret;
	}
	if(bytes_read > 0){
		switch(type)
		{
		case DATA:
			ret = send_data_to_serial(sock, s_port, s_src); break;
		case REPRO: 
			ret = reprogram_mote(sock, s_port); break;
		case ERASE: 
			ret = erase_mote(s_port); break;
		case RESET:
			ret = reset_mote(s_port); break;
		default: break; 
		}
		/* send ack only when the type value is valid */
		if( (type >= 0) && (type < NUM_TYPE) ){
			send_ack_to_server(sock, ret);
		}
	}
	return ret;
}

/* 
 *  			 build_data_packet 
 *
 * Description: build a packet to send back to server (original data from 
 * 				serial port) 
 * Parameters: 
 * 		dpkt, Datapacket includes payload and header, defined proxy.h
 * 		p_packet, pointer to payload, which will be sent 
 * 		type, 0 is ack, 1 data 
 * 		len, length of payload 
 * Return:
 * 		returns entire length of frame to be sent (header + payload)
 * */
static uint8_t build_data_packet(DataPacket* dpkt, uint8_t* p_packet, uint8_t type, uint8_t len)
{
	dpkt->type = type;
	dpkt->rd_cnt = rd_cnt;
	dpkt->wr_cnt = wr_cnt;
	dpkt->len = len;
	memcpy(dpkt->mac, MAC, 8);
	if (p_packet != NULL)
		memcpy(dpkt->data, p_packet, len);
	return offsetof(DataPacket, data)+len;
}

/* 
 *  			 request_from_mote
 *
 * Description: receive a serial AM packet from mote, and send it back to 
 * 				server
 * Parameters: 
 * 		sock, opened socket with server 
 * 		src, opened file descriptor and buffer for serial device 
 */
static int request_from_mote(int sock, serial_source s_src)
{
	uint8_t total_len;
	int len = 0;
	uint16_t bytes_written = 0;
	uint8_t* p_am_packet;
	DataPacket* dpkt;

	p_am_packet = read_serial_packet(s_src, &len);
	if(p_am_packet == NULL){
		perror("request_from_mote, error in reading data from mote\n");
		/* Most likely EAGAIN */
		return errno;
	}
	dpkt = (DataPacket*)malloc(sizeof(DataPacket));
	rd_cnt++; /* inrease read counter */
	total_len = build_data_packet(dpkt, p_am_packet, 0, len);
	bytes_written = send(sock, dpkt, total_len ,0);
	free(p_am_packet); free(dpkt);
	if(bytes_written <= 0){
		/* connection closed by peer */
		return errno;
	}
	return SUCCESS;
}

/* 
 *  			 send_preriodic_message	
 *
 * Description: Send a peridic message to server every 5 seconds 
 * 				(write/read counter)
 * Parameters: 
 * 		sock, open socket 
 * */
static void send_periodic_message(int sock)
{
	uint8_t total_len;
	uint16_t bytes_written = 0;
	DataPacket* dpkt;

	dpkt = (DataPacket*)malloc(sizeof(DataPacket));
	total_len = build_data_packet(dpkt, NULL, 0, 0);
	bytes_written = send(sock, dpkt, total_len, 0);
	if(bytes_written <= 0){
		fprintf(stderr, "request_from_mote, error in sending packet\n");
	}
#ifdef DEBUG
	fprintf(stderr, "%u bytes sent\n", bytes_written);
#endif 
	free(dpkt);
}

/* 
 *  				process_request
 *
 * Description: Process request from both server and box 
 * Parameters: 
 * 		sock, open socket 
 * */
void process_request(int sock, char* s_port, serial_source s_src)
{
	fd_set dummy_mask, temp_mask;
	int n_req = 0;
	int ret;
	int s_fd = serial_source_fd(s_src);
	struct timeval to;
	to.tv_sec = 5;	
	to.tv_usec = 0;

	FD_ZERO(&mask);
	FD_ZERO(&dummy_mask);
	FD_SET(sock, &mask);	/* Request from server */
	FD_SET(s_fd, &mask); 	/* Reqeust from mote   */
	for(;;)
	{
		temp_mask = mask;
		n_req = select(FD_SETSIZE, &temp_mask, &dummy_mask, &dummy_mask, &to);
		if (n_req > 0) {
			if (FD_ISSET(sock, &temp_mask)){
				ret = request_from_server(sock, s_port, s_src);
				switch ( ret ) {
				case EAGAIN: break; /* caused by nonblocking */ 
				case ECONNRESET: clear_socket(sock); return;
				case ENOSERIAL: clear_serial(s_fd, s_src); return;
				}
			}
			else if(FD_ISSET(s_fd, &temp_mask)){
				ret = request_from_mote(sock, s_src);
				switch ( ret ) {
				case EAGAIN: break; /* caused by nonblocking */ 
				case ECONNRESET: clear_socket(sock); return;
				case ENOSERIAL: clear_serial(s_fd, s_src); return;
				}
			}
		}
		else if (n_req == 0){
			/* no request, but timeout */
			if (FD_ISSET(sock, &mask)) send_periodic_message(sock);
		}
		to.tv_sec = 5;	
		to.tv_usec = 0;
	}/* for(;;)*/
}


int main(int argc, char* argv[])
{
	uint16_t tcp_port = 16461;					/* server port */ 
	char* serv_addr; /*[] = "mute.isi.jhu.edu"; 	IP addr or DNS */
	char* s_port;							/* serial port */
	int sock;

	/*
	 * argv[1]: server
	 * argv[2]: serial port 
	 * argv[3]: MAC 
	 */
	if (argc != NUM_ARGS) {
		print_usage(argv[0]);
		exit(1);
	}
	serv_addr = argv[1];
	s_port = argv[2];
	if (strlen(argv[3]) != MACSIZE-1) {
		fprintf(stderr, "Bad MAC address: %s\n", argv[3]);
		exit(1);
	}
	strcpy(MAC, argv[3]);
	/* test whether mote is connected to USB port */
	s_src = open_serial_source(s_port, 115200, 0, stderr_msg);
	if (!s_src) {
		fprintf(stderr, "Failed to open serial port\n");
		exit(1);
	}
	if ( (sock = connect_to_server(serv_addr, tcp_port)) == -1 ) {
		exit(1);
	} 
	process_request(sock, s_port, s_src);
	close_serial_source(s_src);
	r_close(sock);
	return 0;
}
