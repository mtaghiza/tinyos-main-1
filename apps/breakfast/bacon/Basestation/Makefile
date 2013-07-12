COMPONENT=BaseStationAppC

CFLAGS += -I$(TOSROOT)/apps/breakfast/bacon/settingsStorage
CFLAGS += -I$(TOSDIR)/chips/msp430/tlvStorage

CFLAGS += -I$(TOSDIR)/lib/printf
CFLAGS += -I$(TOSDIR)/lib/serial
CFLAGS += -I$(TOSDIR)/lib/cxl/debug
CFLAGS += -I$(TOSDIR)/lib/cxl/am
CFLAGS += -I$(TOSDIR)/lib/cxl/mac
CFLAGS += -I$(TOSDIR)/lib/cxl/link
CFLAGS += -I$(TOSDIR)/lib/cxl/packet
CFLAGS += -I$(TOSDIR)/lib/cxl/scheduler
CFLAGS += -I$(TOSDIR)/lib/cx/routing
CFLAGS += -I$(TOSDIR)/lib/cx/debug
CFLAGS += -I$(TOSDIR)/lib/rf1a-tdma/timer

PFLAGS+=-DMSP430XV2_DCO_CONFIG=MSP430XV2_DCO_32MHz_RSEL6
CFLAGS+=-DXT2_SMCLK

#CFLAGS+= -DTOSH_DATA_LENGTH=109
CFLAGS+= -DRF1A_FEC_ENABLED=1
CFLAGS+= -DRF1A_WHITENING_ENABLED=1
CFLAGS += -DPATABLE0_SETTING=0x2D
CFLAGS+= -DRF1A_AUTOCAL=0

PROBE_INTERVAL?=1024UL
CFLAGS += -DPROBE_INTERVAL=$(PROBE_INTERVAL)
CFLAGS += -DLPP_SLEEP_TIMEOUT=6144UL

CX_MAX_DEPTH?=5
CFLAGS += -DCX_MAX_DEPTH=$(CX_MAX_DEPTH)

CFLAGS += -DCX_BASESTATION=1

CFLAGS += -DAM_ID_FROM_FLASH=0

ENABLE_PRINTF ?= 1
CFLAGS += -DENABLE_PRINTF=$(ENABLE_PRINTF)
CFLAGS += -DDL_LPP=DL_WARN
CFLAGS += -DDL_LINK=DL_WARN
CFLAGS += -DDL_SCHED=DL_WARN
CFLAGS += -DDL_ROUTER=DL_INFO

CFLAGS +=-DCC430_PIN_DEBUG=1
STORAGEDIR = $(TOSDIR)/platforms/bacon/chips/stm25p

#TESTING ONLY
LPP_DEFAULT_PROBE_INTERVAL?=1024UL
CFLAGS += -DLPP_DEFAULT_PROBE_INTERVAL=$(LPP_DEFAULT_PROBE_INTERVAL)

CX_MAX_DEPTH?=5
CFLAGS += -DCX_MAX_DEPTH=$(CX_MAX_DEPTH)

#LPP control messages
LPPMIGDIR = lpp
MIGCLASSES = $(LPPMIGDIR)/CxLppCts.py $(LPPMIGDIR)/CxLppSleep.py $(LPPMIGDIR)/CxLppWakeup.py 

CXMIGDIR = cx/messages
MIGCLASSES += $(CXMIGDIR)/CxDownload.py $(CXMIGDIR)/CtrlAck.py $(CXMIGDIR)/CxDownloadFinished.py 

APMIGDIR = autoPush/messages
MIGCLASSES += $(APMIGDIR)/CxRecordRequestMsg.py $(APMIGDIR)/LogRecordDataMsg.py

PINGMIGDIR = $(APMIGDIR)
MIGCLASSES += $(PINGMIGDIR)/PingMsg.py $(PINGMIGDIR)/PongMsg.py 

PRINTFMIGDIR = $(APMIGDIR)
MIGCLASSES += $(PRINTFMIGDIR)/PrintfMsg.py

#printf
CFLAGS += -DNEW_PRINTF_SEMANTICS

$(LPPMIGDIR):
	mkdir -p $(LPPMIGDIR)

$(LPPMIGDIR)/%.py: $(LPPMIGDIR)
	genMig.sh $(PLATFORM) $(TOSDIR)/lib/cxl/mac/CXMac.h $@ $(CFLAGS) 

$(CXMIGDIR):
	mkdir -p $(CXMIGDIR)

$(CXMIGDIR)/%.py: $(CXMIGDIR)
	genMig.sh $(PLATFORM) basestation.h $@ $(CFLAGS) 

$(PINGMIGDIR):
	mkdir -p $(PINGMIGDIR)

$(PINGMIGDIR)/%.py: $(PINGMIGDIR)
	genMig.sh $(PLATFORM) $(TOSROOT)/apps/breakfast/bacon/Ping/ping.h $@ $(CFLAGS) 

$(APMIGDIR):
	mkdir -p $(APMIGDIR)

$(APMIGDIR)/CxRecordRequestMsg.py: $(APMIGDIR)
	genMig.sh $(PLATFORM) $(TOSROOT)/apps/breakfast/bacon/autoPush/RecordRequest.h $@ $(CFLAGS)

$(APMIGDIR)/LogRecordDataMsg.py: $(APMIGDIR) 
	genMig.sh $(PLATFORM) $(STORAGEDIR)/RecordStorage.h $@ $(CFLAGS)

$(PRINTFMIGDIR):
	mkdir -p $(PINGMIGDIR)

$(PRINTFMIGDIR)/PrintfMsg.py: 
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=PrintfMsg $(TOSDIR)/lib/printf/printf.h printf_msg -o $@

migClasses: $(MIGCLASSES)

include $(MAKERULES)
