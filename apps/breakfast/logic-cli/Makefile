CC = g++

#for 64-bit binaries
LINKDEPS = -lSaleaeDevice64

##for 32-bit binaries
#LINKDEPS = -lSaleaeDevice

OUTDIR = bin
SRCDIR = src
LIBDIR = lib
INCDIR = include
EXE = $(OUTDIR)/logic-cli

#Runtime lib path should include <binary's dir>../lib
#  so that if you don't install Saleae's lib to one of the standard
#  locations, as long as you preserve this directory structure it will
#  find it.
LDFLAGS = $(LINKDEPS) -Wl,-rpath,'$$ORIGIN:$$ORIGIN/../lib' -L $(LIBDIR)
CFLAGS += -I$(INCDIR)
CFLAGS += -O3 -w -c -fpic -pthread -std=c++0x

all: outdir $(EXE)

$(EXE): $(EXE).o
	$(CC) -o $@ $^ $(LDFLAGS)

$(OUTDIR)/%.o: $(SRCDIR)/%.cpp 
	$(CC) -c $(CFLAGS) -o $@ $<

outdir:
	mkdir -p $(OUTDIR)

.PHONY: clean

clean:
	rm $(OUTDIR)/*.o
	rm $(EXE)
	rmdir $(OUTDIR)
