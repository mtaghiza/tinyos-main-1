DEBUG=-DDEBUG
CFLAGS=-Wall

proxy: proxy.c serialsource.c restart.c proxy.h
	$(CC) -o proxy $(DEBUG) $(CFLAGS) $^

clean:
	rm -f proxy *~
