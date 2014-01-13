COMPONENT=TestAppC
MIGDIR = mig
STORAGEDIR = $(TOSDIR)/platforms/bacon/chips/stm25p

MIGCLASSES = $(MIGDIR)/LogRecordDataMsg.py
MIGCLASSES += $(MIGDIR)/PrintfMsg.py 
MIGCLASSES += $(MIGDIR)/CxRecordRequestMsg.py 

#for serial AM printf
RAW_SERIAL_PRINTF=0
CFLAGS += -DRAW_SERIAL_PRINTF=$(RAW_SERIAL_PRINTF)
ENABLE_PRINTF ?= 1
CFLAGS += -DENABLE_PRINTF=$(ENABLE_PRINTF)
CFLAGS += -DNEW_PRINTF_SEMANTICS
CFLAGS += -I$(TOSDIR)/lib/printf
CFLAGS += -I$(TOSDIR)/lib/serial
CFLAGS += -DMAX_RECORD_PACKET_LEN=102
#CFLAGS += -DTOSH_DATA_LENGTH=110

CFLAGS+=-DSINGLE_RECORD_READ=1

#for settings storage
CFLAGS += -I$(TOSROOT)/apps/breakfast/bacon/testAutoPush
CFLAGS += -I$(TOSROOT)/apps/breakfast/bacon/settingsStorage
CFLAGS += -I$(TOSROOT)/apps/breakfast/bacon/autoPush
CFLAGS += -I$(TOSROOT)/apps/breakfast/bacon/Router
CFLAGS += -I$(TOSROOT)/apps/breakfast/bacon/RebootCounter
CFLAGS += -I$(TOSDIR)/lib/cxl/debug
CFLAGS += -I$(TOSDIR)/lib/cxl/packet
CFLAGS += -I$(TOSDIR)/lib/cxl/link
#CFLAGS += -I$(TOSROOT)/apps/breakfast/bacon/sdCard
#CFLAGS += -I$(TOSROOT)/apps/breakfast/bacon/sdCard/stm25p
CFLAGS += -I$(TOSDIR)/chips/msp430/msp430xv2/internalFlash
CFLAGS += -I$(TOSDIR)/chips/msp430/tlvStorage

# PFLAGS+=-DMSP430XV2_DCO_CONFIG=MSP430XV2_DCO_32MHz_RSEL6
# CFLAGS+=-DXT2_SMCLK
# CFLAGS+=-DXT2_DC_ENABLED=0

$(MIGDIR): 
	mkdir -p $(MIGDIR)

$(MIGDIR)/PrintfMsg.py: $(MIGDIR) $(TOSDIR)/lib/printf/printf.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=PrintfMsg $(TOSDIR)/lib/printf/printf.h printf_msg -o $@

$(MIGDIR)/CxRecordRequestMsg.py: $(MIGDIR) $(TOSROOT)/apps/breakfast/bacon/autoPush/RecordRequest.h
	genMig.sh $(PLATFORM) $(TOSROOT)/apps/breakfast/bacon/autoPush/RecordRequest.h $@ $(CFLAGS)

$(MIGDIR)/LogRecordDataMsg.py: $(MIGDIR) $(STORAGEDIR)/RecordStorage.h
	genMig.sh $(PLATFORM) $(STORAGEDIR)/RecordStorage.h $@ $(CFLAGS)


migClasses: $(MIGCLASSES)

include $(MAKERULES)
