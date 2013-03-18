COMPONENT=TestAppC

CFLAGS+=-I$(TOSDIR)/lib/serialprintf
CFLAGS += -I$(TOSDIR)/lib/priorityQueue

CFLAGS += -I$(TOSDIR)/lib/cx/link
CFLAGS += -I$(TOSDIR)/lib/cx/packet
CFLAGS += -I$(TOSDIR)/lib/cx/debug
CFLAGS += -I$(TOSDIR)/lib/rf1a-tdma/timer

PFLAGS+=-DMSP430XV2_DCO_CONFIG=MSP430XV2_DCO_32MHz_RSEL6
CFLAGS+=-DXT2_SMCLK

CFLAGS +=-DENABLE_TIMESTAMPING=1

#NB: length field is 8 bits: so if we are using FEC, we need to make
# sure that the total packet length is less than this.
CFLAGS+= -DTOSH_DATA_LENGTH=110
CFLAGS+= -DRF1A_FEC_ENABLED=1
CFLAGS+= -DPATABLE0_SETTING=0x8D

#Debug settings
#enable link layer printf's
CFLAGS += -DDEBUG_LINK=0
#toggle P1.1 at every frame boundary
CFLAGS += -DLINK_DEBUG_FRAME_BOUNDARIES=0

include $(MAKERULES)

