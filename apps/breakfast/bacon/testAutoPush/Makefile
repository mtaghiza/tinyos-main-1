COMPONENT=TestAppC
MIGDIR = mig
STORAGEDIR = $(TOSDIR)/platforms/bacon/chips/stm25p

MIGCLASSES = $(MIGDIR)/LogRecordDataMsg.py
MIGCLASSES += $(MIGDIR)/PrintfMsg.py 

#for serial AM printf
CFLAGS += -DNEW_PRINTF_SEMANTICS
CFLAGS += -I$(TOSDIR)/lib/printf
CFLAGS += -I$(TOSDIR)/lib/serial
CFLAGS +=-DTOSH_DATA_LENGTH=140

CFLAGS+=-DSINGLE_RECORD_READ=1

#for settings storage
CFLAGS += -I$(TOSROOT)/apps/breakfast/bacon/settingsStorage
CFLAGS += -I$(TOSROOT)/apps/breakfast/bacon/autoPush
CFLAGS += -I$(TOSDIR)/chips/msp430/msp430xv2/internalFlash
CFLAGS += -I$(TOSDIR)/chips/msp430/tlvStorage

$(MIGDIR): 
	mkdir -p $(MIGDIR)

$(MIGDIR)/PrintfMsg.py: $(MIGDIR) $(TOSDIR)/lib/printf/printf.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=PrintfMsg $(TOSDIR)/lib/printf/printf.h printf_msg -o $@

$(MIGDIR)/%.py: $(MIGDIR) $(STORAGEDIR)/RecordStorage.h
	genMig.sh $(PLATFORM) $(STORAGEDIR)/RecordStorage.h $@ $(CFLAGS)

migClasses: $(MIGCLASSES)

include $(MAKERULES)
