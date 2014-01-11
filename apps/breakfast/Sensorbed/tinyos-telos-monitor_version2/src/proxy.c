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
 * @author Doug Carlson <carlson@cs.jhu.ed>
 * - Added serial # check to determine BSL version
 * 
 * @version $Revision$ $Date$
 * 
 */

#include "proxy.h"
#include "serialsource.h"

int s_fd = 0; 		  /* serial file descriptor */
char MAC[MACSIZE];
struct termios newtio;

static void print_usage(char* program_name)
{
	fprintf(stderr, "Usage: %s [IP address or DNS] [serial port] [MAC]\n", program_name);
	fprintf(stderr, "\tIP address or DNS\n");
	fprintf(stderr, "\tserial port\tSerial port of box. (ex: /dev/ttyUSB0)\n"); 
	fprintf(stderr, "\tMAC\t\tMAC address of the mote. (ex: M4AN1DBR)\n"); 
}

void print_error(char* msg)
{
#ifdef DEBUG
	fprintf(stderr, "%s", msg);
#endif
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

	/* Remove new line or carriage return, just in case */
	c = strchr(serv_info, '\n');
	if ( c ) *c = '\0';
	c = strchr(serv_info, '\r');
	if ( c ) *c = '\0';
#ifdef DEBUG
	fprintf(stderr, "Trying to connect...\nServer Address: %s, Port: %u\n", serv_info, port_num);
#endif 
	if( (sock = socket(PF_INET, SOCK_STREAM, 0)) < 0){
		print_error("DEBUG:[connect_to_server] socket error\n");
		return FAIL;
	}
	bzero(&serv_addr, sizeof(serv_addr));
	serv_addr.sin_family = AF_INET;
	if( (ip_addr = inet_addr(serv_info)) == INADDR_NONE){
		/* If user entered DNS address, instead of IP address */
		p_h_ent = gethostbyname(serv_info);
		if(p_h_ent == NULL){
			print_error("DEBUG:[connect_to_server] gethostbyname() error\n");
			return FAIL;
		}
		memcpy(&h_ent, p_h_ent, sizeof(h_ent));
		memcpy(&ip_addr, h_ent.h_addr, sizeof(in_addr_t));
	}
	serv_addr.sin_addr.s_addr = ip_addr;
	serv_addr.sin_port = htons(port_num);
	if(connect(sock, (struct sockaddr*)&serv_addr, sizeof(struct sockaddr_in)) == -1){
		print_error("DEBUG:[connect_to_server] connect error\n");
		return FAIL;
	}
#ifdef DEBUG
	fprintf(stderr, "DEBUG:[connect_to_server] Connection Established...\n");
#endif 
	return sock;
}

/* 
 *  			send_ack_to_server
 *
 * Description: report the status message(error) of the task that has finished
 * Parameters: 
 * 		sock, open socket with server 
 * 		ret, report error value to server 
 */
static void send_ack_to_server(int sock, uint8_t ret)
{
	int bytes_written = 0;
	AckPacket* ack = (AckPacket*)malloc(sizeof(AckPacket));
	ack -> type = 1; 
	ack -> error = ret;
	
	bytes_written = r_write(sock, ack, sizeof(AckPacket));
	free(ack);
	if( bytes_written <= 0){
		print_error("DEBUG: error in sending ack to server\n");
	}
	else{
		print_error("DEBUG: successful in sending ack to server\n");
	}
}

/* 
 *  			send_data_to_serial
 *
 * Description: if a user sends data for mote, proxy forward it to the mote 
 * Parameters: 
 * 		sock, open socket with server 
 * 		s_port, fully-qualified path name of serial dev, e.g. /dev/ttyUSB0
 * 		src, opened file descriptor and buffer for serial device 
 */
static uint8_t send_data_to_serial(int sock)
{
	uint8_t read_bytes = 0;
	char stream[TOS_MAX], i;
	
	read_bytes = r_read(sock, stream, TOS_MAX);
	if ( (read_bytes == 0) || (read_bytes > TOS_MAX)) {
		print_error("DEBUG:[send_data_to_serial] connection reset by peer\n");
		return FAIL;
	}
#ifdef DEBUG
	for (i = 0; i < read_bytes; i++)
		fprintf(stderr, "%d ", stream[i]);
	fprintf(stderr, "\n");
#endif
	if( r_write(s_fd, stream, read_bytes) <= 0){
		print_error("DEBUG: error in writing data to serial\n");
		return FAIL;
	}
	print_error("DEBUG: success in writing data to serial\n");
	return SUCCESS;
}

/* 
 *  			reprogram_mote 
 *
 * Description: reprogram mote with ihex file delivered from server 
 * Parameters: 
 * 		sock, an opened socket for reprogramming 
 * 		s_port, fully-qualified path name of serial dev, e.g. /dev/ttyUSB0
 */
static uint8_t reprogram_mote(int sock, char* s_port)
{
	uint32_t size = 0, ptr;
	uint32_t temp_size = 0;
	uint32_t bytes = 0;
	char filename[23]; 
	int fd;
	pid_t childpid;
	char* ihex;

	/* temporarily close serial port for reprogramming */
	r_close(s_fd);

	bytes = recv(sock, &size, REP_SIZE, 0);
	if(bytes != REP_SIZE){
		print_error("DEBUG: error in reading size field\n");
		return FAIL;
	}
	temp_size = ntohl(size);
	size = temp_size;
	ihex = (char*)malloc(size);
	bytes = 0; ptr = 0;
	while( (temp_size > 0) && (bytes = recv(sock, ihex+ptr, temp_size, 0)) > 0 ){
		temp_size = temp_size - bytes;
		ptr = ptr + bytes;
	}
	sprintf(filename, "main.ihex.out.%s", MAC);
	fd = r_open3(filename, FLAGS, PERMS);
	if (fd == -1) {
		print_error("error in opening file\n");
		return FAIL;
	}
	if ( (bytes = r_write(fd, ihex, size)) == -1){
		print_error("error in writing in file\n");
		return FAIL;
	}
#ifdef DEBUG
	fprintf(stderr, "DEBUG: sending hex file successfully: %d written %d bytes received\n", bytes, size);
#endif
	if (r_close(fd) == -1) {
		print_error("Error in closing file\n");	
		return FAIL;
	}
	free(ihex);

    int childStatus;
    int reprogramAttempts;
    for (reprogramAttempts = 1; reprogramAttempts <= REPROGRAM_ATTEMPT_LIMIT; reprogramAttempts ++){
        /* fork extra process to handle request */
        childpid = fork();
        if (childpid == -1) {
        	print_error("error in forking child\n");
        	return FAIL;
        }
        /* child code */
        if (childpid == 0) {
              if (strncmp(MAC, TELOS_MAC_PREFIX, TELOS_MAC_PREFIX_LEN) == 0){
                printf("Programming telos\n");
        	  execl("/usr/bin/telosb-cppbsl", "telosb-cppbsl", "-b", "-p", filename, "-c", s_port, (char*)NULL); 
              } else {
                printf("Programming non-telos\n");
        	  execl("/usr/bin/cc430-cppbsl", "cc430-cppbsl", "-R", "-e",
                  "-p", filename, "-c", s_port, (char*)NULL);
              }
        	print_error("error in executing child process\n");
        	return FAIL;
        }
        /* parent code */
        if (childpid != r_wait(&childStatus)) {
        	print_error("Parent failed to wait\n");
        	return FAIL;
        }
        if (WIFEXITED(childStatus) && WEXITSTATUS(childStatus) == 0){
          break;
        }
    }

	/* Delete file */
	if(remove(filename) != 0){
		print_error("DEBUG: error in deleting ihex file\n");
	}
	if ( (s_fd = r_open3(s_port, SFLAGS, PERMS)) == -1) {
		print_error("DEBUG: error in opening serial port\n");
		exit(1);
	}
    if ( (tcflush(s_fd, TCIFLUSH) < 0) || (tcsetattr(s_fd, TCSANOW, &newtio) < 0)){
		print_error("DEBUG: error in flushing serial port\n");
	}
    if (reprogramAttempts > REPROGRAM_ATTEMPT_LIMIT){
      return FAIL;
    }else{
	  return SUCCESS;
    }
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

	if (r_close(s_fd) == -1) {
		print_error("error in closing file\n");
		return FAIL;
	}
	/* fork extra process to handle request */
	childpid = fork();
	if (childpid == -1) {
		print_error("error in forking child\n");
		return FAIL;
	}
	/* child code */
	if (childpid == 0) {
        if (strncmp(MAC, TELOS_MAC_PREFIX, TELOS_MAC_PREFIX_LEN) == 0){
            printf("erase telos\n");
		    execl("/usr/bin/telosb-cppbsl", "telosb-cppbsl", "--telosb", "-c", s_port, "-e",  (char*)NULL); 
        } else {
            printf("erase non-telos\n");
		    execl("/usr/bin/cc430-cppbsl", "cc430-cppbsl", "-R", "-e",
              "-c", s_port, (char*)NULL); 
        }
		print_error("error in executing child process\n");
		return FAIL;
	}
	/* parent code */
	if (childpid != r_wait(NULL)) {
		print_error("Parent failed to wait\n");
		return FAIL;
	}
#ifdef DEBUG
	fprintf(stderr, "DEBUG: erase mote\n");
#endif
	if ( (s_fd = r_open3(s_port, SFLAGS, PERMS)) == -1) {
		print_error("DEBUG: error in opening serial port\n");
		exit(1);
	}
    if ( (tcflush(s_fd, TCIFLUSH) < 0) || (tcsetattr(s_fd, TCSANOW, &newtio) < 0) ){
		print_error("DEBUG: error in flushing serial port\n");
	}
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

	if (r_close(s_fd) == -1) {
		print_error("error in closing file\n");
		return FAIL;
	}
	/* fork extra process to handle request */
	childpid = fork();
	if (childpid == -1) {
		print_error("error in forking child\n");
		return FAIL;
	}
	/* child code */
	if (childpid == 0) {
        if (strncmp(MAC, TELOS_MAC_PREFIX, TELOS_MAC_PREFIX_LEN) == 0){
            printf("Resetting Telos\n");
		    execl("/usr/bin/telosb-cppbsl", "telosb-cppbsl", "--telosb", "-c",
              s_port, "-r", (char*)NULL);
        } else {
            printf("Resetting Non-Telos\n");
		    execl("/usr/bin/cc430-cppbsl", "cc430-cppbsl", "-R", "-r",
              "-c", s_port, (char*)NULL);
        }
		print_error("error in executing child process\n");
		return FAIL;
	}
	/* parent code */
	if (childpid != r_wait(NULL)) {
		print_error("Parent failed to wait\n");
		return FAIL;
	}
	if ( (s_fd = r_open3(s_port, SFLAGS, PERMS)) == -1) {
		print_error("DEBUG: error in opening serial port\n");
		exit(1);
	}
    if ( (tcflush(s_fd, TCIFLUSH) < 0) || (tcsetattr(s_fd, TCSANOW, &newtio) < 0) ){
		print_error("DEBUG: error in flushing serial port\n");
	}
	return SUCCESS;
}

/* 
 *  			 handle_reprogram_request
 *
 * Description: when request from server arrives, parse the request by type
 * Parameters: 
 * 		sock, opened socket with server 
 * 		s_port, fully-qualified path name of serial dev, e.g. /dev/ttyUSB0
 */
static int handle_reprogram_request(int sock, char* s_port)
{
	int bytes_read, ret = FAIL;
	uint8_t type = 0;

	bytes_read = recv(sock, &type, TYPESIZE, 0);
	if( bytes_read <= 0){
		print_error("DEBUG: disconnected by peer\n");
		return ret;
	}
	switch(type)
	{
	case REPRO: 
		ret = reprogram_mote(sock, s_port); break;
	case ERASE: 
		ret = erase_mote(s_port); break;
	case RESET:
		ret = reset_mote(s_port); break;
	default: 
		print_error("DEBUG: unknown type\n");
		break; 
	}
	/* send ack only when the type value is valid */
	if ( (type > 0) && (type < 4)) {
		send_ack_to_server(sock, ret);
	}
	return SUCCESS;
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
static void build_data_packet(DataPacket* dpkt, uint8_t type)
{
	dpkt->type = type;
	memcpy(dpkt->mac, MAC, 8);
}

/* 
 *  			 request_from_mote
 *
 * Description: receive a serial AM packet from mote, and send it to server
 * Parameter: 
 * 		sock, opened socket with server 
 */
static int request_from_mote(int sock, char* s_port)
{
	uint8_t stream[TOS_MAX];
	int bytes_read, bytes_written, i;

	bytes_read = r_read(s_fd, stream, TOS_MAX);
	if ( (bytes_read == 1) && (stream[0] == 0) ){
		print_error("DEBUG:[request_from_mote] serial reset\n");
		return SUCCESS;
	}
	if (bytes_read <= 0) {
		print_error("DEBUG:[request_from_mote] error in reading data from serial\n");	
		return FAIL;
	}
#ifdef DEBUG
	fprintf(stderr, "* stream: ");
	for( i = 0; i < bytes_read; i++){
		fprintf(stderr, "%02x ", stream[i]);
	}
	fprintf(stderr, "length: %d\n", bytes_read);
#endif
	bytes_written = r_write(sock, stream, bytes_read);
	if ( bytes_written <= 0 ){
		print_error("DEBUG:[request_from_mote] error in sending mote's data to server\n");
		return FAIL;
	}
	return SUCCESS;
}

/* 
 *  			 send_preriodic_message	
 *
 * Description: Send a peridic message to server every 5 seconds 
 * 				(write/read counter)
 * Parameters: 
 * 		sock, open socket to server 
 * */
static int send_periodic_message(int sock)
{
	uint8_t bytes_written = 0;
	DataPacket* dpkt;

	dpkt = (DataPacket*)malloc(sizeof(DataPacket));
	build_data_packet(dpkt, 0);

	bytes_written = r_write(sock, dpkt, sizeof(DataPacket));
	free(dpkt);
	if (bytes_written <= 0){
		print_error("DEBUG:[send_periodic_message] error in sending periodic packet\n");
		return FAIL;
	}
#ifdef DEBUG
	fprintf(stderr, "DEBUG:[send_periodic_message] periodic, %u bytes sent\n", bytes_written);
#endif 
	return SUCCESS;
}

/* 
 *  				process_request
 *
 * Description: Process request from both server and box 
 * Parameters: 
 * 		sock, open socket 
 * */
int process_request(int main_sock, int stream_sock, char* s_port)
{
	fd_set dummy_mask, temp_mask, mask;
	int n_req = 0;
	int ret = FAIL;
	struct timeval to;

	if ( r_write(stream_sock, MAC, 8) <= 0) {
		print_error("DEBUG:[process_request] error in sending MAC to stream socket\n");
		return FAIL;  
	}
	if  (send_periodic_message(main_sock) == FAIL){
		print_error("DEBUG:[process_request] sending the first periodic message\n");
		return FAIL;
	}
	to.tv_sec = 5;	
	to.tv_usec = 0;
	FD_ZERO(&mask);
	FD_ZERO(&dummy_mask);
	FD_SET(main_sock, &mask);	/* for maintanence, periodic keep alive and reprogramming */
	FD_SET(stream_sock, &mask);	/* stream from server(or user) to mote */
	FD_SET(s_fd, &mask); 		/* stream from mote   */
	for( ; ; )
	{
		temp_mask = mask;
		n_req = select(FD_SETSIZE, &temp_mask, &dummy_mask, &dummy_mask, &to);
		if (n_req > 0) {
			if(FD_ISSET(s_fd, &temp_mask)){
				ret = request_from_mote(stream_sock, s_port);
			}
			else if(FD_ISSET(main_sock, &temp_mask)){
				ret = handle_reprogram_request(main_sock, s_port);
			}
			else if(FD_ISSET(stream_sock, &temp_mask)){
				ret = send_data_to_serial(stream_sock);
			}
		}
		else if (n_req == 0){
			/* no request, but timeout every 5 seconds */
			if (FD_ISSET(main_sock, &mask)) {
				ret = send_periodic_message(main_sock);
			}
		}
		if (ret != SUCCESS) { 
			break;
		}
		to.tv_sec = 5;	
		to.tv_usec = 0;
	} /* for(;;) */
	return ret;
}

int main(int argc, char* argv[])
{
	uint16_t main_port 	 = 16461; /* port for maintainance */ 
	uint16_t stream_port = 16463; /* port for data stream */ 
	char* serv_addr; 	       	  /* IP addr or DNS */
	char* s_port;			   	  /* serial port, e.g. /dev/ttyUSB0 */
	int stream_sock, main_sock, ret;
	tcflag_t baudflag = B115200;

	memset(&newtio, 0, sizeof(newtio));
	newtio.c_cflag = CS8 | CLOCAL | CREAD;
	newtio.c_iflag = IGNPAR | IGNBRK;
	cfsetispeed(&newtio, baudflag);
	cfsetospeed(&newtio, baudflag);
	newtio.c_oflag = 0;

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
		print_error("DEBUG: MAC length invalid\n");
		exit(1);
	}
	strcpy(MAC, argv[3]);

    //bacon hack: needs reset after being plugged in before it starts
    //running
    if (strncmp(MAC, TELOS_MAC_PREFIX, TELOS_MAC_PREFIX_LEN) != 0){
        if( SUCCESS != reset_mote(s_port)){
          print_error("DEBUG: error resetting non-telos mote prior to connection\n");
          exit(1);
        }
    }
	if ( (s_fd = r_open3(s_port, SFLAGS, PERMS)) <= 0) {
		print_error("DEBUG: error in opening serial\n");
		exit(1);
	}
    if ( (tcflush(s_fd, TCIFLUSH) < 0) || (tcsetattr(s_fd, TCSANOW, &newtio) < 0) ){
		print_error("DEBUG: error in flushing serial\n");
		r_close(s_fd);
		exit(1);
	}
	if ( (main_sock = connect_to_server(serv_addr, main_port)) <= 0) {
		print_error("DEBUG: connection to server failed\n");
		r_close(s_fd);
		exit(1);
	} 
	sleep(2);
	if ( (stream_sock = connect_to_server(serv_addr, stream_port)) <= 0) {
		print_error("DEBUG: failed to connect to stream channel\n");
		r_close(s_fd);
		r_close(main_sock);
		exit(1);
	}
	ret = process_request(main_sock, stream_sock, s_port);
	if (ret != SUCCESS){
		r_close(s_fd);	r_close(main_sock); r_close(stream_sock);
	}
	return 0;
}
