#fill in with path to your cross-compiler (or pass as argument)
CC=~/Documents/projects/bacon/kamikaze_7.09/staging_dir_armeb/bin/armeb-linux-uclibc-gcc
#CC=gcc
#DEBUG=-DDEBUG
CFLAGS=-Wall
CFLAGS+=-I../../tinyos-telos-monitor/src

proxy:
	$(CC) -o proxy $(DEBUG) $(CFLAGS) proxy.c restart.c 

clean:
	rm -f proxy 
