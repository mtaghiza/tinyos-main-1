COMPONENT=TestC

CX_MASTER?=1
CFLAGS += -DCX_MASTER=$(CX_MASTER)

CFLAGS+=-I$(TOSDIR)/lib/serialprintf
CFLAGS += -I$(TOSDIR)/lib/priorityQueue

CFLAGS += -I$(TOSDIR)/lib/cx
CFLAGS += -I$(TOSDIR)/lib/cx/scheduler
CFLAGS += -I$(TOSDIR)/lib/cx/network
CFLAGS += -I$(TOSDIR)/lib/cx/link
CFLAGS += -I$(TOSDIR)/lib/cx/packet
CFLAGS += -I$(TOSDIR)/lib/cx/debug
CFLAGS += -I$(TOSDIR)/lib/rf1a-tdma/timer

CFLAGS += -I$(TOSROOT)/apps/breakfast/util

PFLAGS+=-DMSP430XV2_DCO_CONFIG=MSP430XV2_DCO_32MHz_RSEL6
CFLAGS+=-DXT2_SMCLK

CFLAGS += -DCX_SELF_RETX=1

CFLAGS +=-DENABLE_TIMESTAMPING=1

#160 frames = 5 seconds
CFLAGS +=-DCX_DEFAULT_CYCLE_LENGTH=200
CFLAGS +=-DCX_DEFAULT_SLOT_LENGTH=10
CFLAGS +=-DCX_DEFAULT_MAX_DEPTH=4

#NB: length field is 8 bits: so if we are using FEC, we need to make
# sure that the total packet length is less than this.
CFLAGS+= -DTOSH_DATA_LENGTH=109
CFLAGS+= -DRF1A_FEC_ENABLED=1
CFLAGS+= -DPATABLE0_SETTING=0x8D

#Debug settings
#enable link layer printf's
CFLAGS += -DDEBUG_LINK=1
CFLAGS += -DDEBUG_SKEW=1
CFLAGS += -DDEBUG_SCHED=1
#toggle P1.1 at every frame boundary
CFLAGS += -DLINK_DEBUG_FRAME_BOUNDARIES=0
#Set P1.1 at wakeup, clear at sleep
CFLAGS += -DLINK_DEBUG_WAKEUP=1

#CFLAGS += -DFRAMELEN_32K=2048UL
#CFLAGS += -DFRAMELEN_6_5M=406250UL
CFLAGS += -DDUMMY_CRC=0
CFLAGS += -DCX_ENABLE_SKEW_CORRECTION=1

include $(MAKERULES)

