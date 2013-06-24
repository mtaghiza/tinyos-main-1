COMPONENT=BaseStationAppC

CFLAGS += -I$(TOSDIR)/lib/printf
CFLAGS += -I$(TOSDIR)/lib/serial
CFLAGS += -I$(TOSDIR)/lib/cxl/debug
CFLAGS += -I$(TOSDIR)/lib/cxl/am
CFLAGS += -I$(TOSDIR)/lib/cxl/mac
CFLAGS += -I$(TOSDIR)/lib/cxl/link
CFLAGS += -I$(TOSDIR)/lib/cxl/packet
CFLAGS += -I$(TOSDIR)/lib/rf1a-tdma/timer

PFLAGS+=-DMSP430XV2_DCO_CONFIG=MSP430XV2_DCO_32MHz_RSEL6
CFLAGS+=-DXT2_SMCLK

#CFLAGS+= -DTOSH_DATA_LENGTH=109
CFLAGS+= -DRF1A_FEC_ENABLED=1
CFLAGS+= -DRF1A_WHITENING_ENABLED=1
CFLAGS += -DPATABLE0_SETTING=0x8D
CFLAGS+= -DRF1A_AUTOCAL=1

PROBE_INTERVAL?=1024UL
CFLAGS += -DPROBE_INTERVAL=$(PROBE_INTERVAL)
CFLAGS += -DLPP_SLEEP_TIMEOUT=6144UL

CFLAGS += -DCX_BASESTATION=1

CFLAGS += -DAM_ID_FROM_FLASH=0

ENABLE_PRINTF ?= 1
CFLAGS += -DENABLE_PRINTF=$(ENABLE_PRINTF)
CFLAGS += -DDL_LPP=DL_WARN
CFLAGS += -DDL_LINK=DL_WARN


MIGDIR = mig
#LPP control messages
MIGCLASSES = $(MIGDIR)/CxLppCts.py $(MIGDIR)/CxLppSleep.py $(MIGDIR)/CxLppWakeup.py
#printf
CFLAGS += -DNEW_PRINTF_SEMANTICS
MIGCLASSES += $(MIGDIR)/PrintfMsg.py 
MIGCLASSES += $(MIGDIR)/TestPayload.py 

$(MIGDIR): 
	mkdir -p $(MIGDIR)

$(MIGDIR)/%.py: $(MIGDIR) 
	genMig.sh $(PLATFORM) $(TOSDIR)/lib/cxl/mac/CXMac.h $@ $(CFLAGS) 

$(MIGDIR)/TestPayload.py: $(MIGDIR) 
	genMig.sh $(PLATFORM) $(TOSROOT)/apps/breakfast/bacon/cxUnitTests/cxl/testAM/test.h $@ $(CFLAGS) 

$(MIGDIR)/PrintfMsg.py: $(MIGDIR) $(TOSDIR)/lib/printf/printf.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=PrintfMsg $(TOSDIR)/lib/printf/printf.h printf_msg -o $@

migClasses: $(MIGCLASSES)

include $(MAKERULES)
