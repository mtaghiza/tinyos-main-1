COMPONENT=MetadataAppC
MIGDIR = mig

##couldn't entice Make to run this command...
#grep 'msg{' ctrl_messages.h | awk '{print $3}' | tr -d '{' | sed -re 's,(_|^)([a-z]),\u\2,g' -e 's,^,$(MIGDIR)/,g' -e 's,$,.py,g'
MIGCLASSES =
MIGCLASSES += $(MIGDIR)/PrintfMsg.py 

USE_AM_RADIO?=0
CFLAGS += -DUSE_AM_RADIO=$(USE_AM_RADIO)

CFLAGS += -DNEW_PRINTF_SEMANTICS
CFLAGS += -I$(TOSDIR)/lib/printf
CFLAGS += -I$(TOSDIR)/lib/serial
#CFLAGS += -I$(TOSDIR)/lib/dualAM
CFLAGS += -Ihandlers
CFLAGS += -I.
CFLAGS +=-DTOSH_DATA_LENGTH=140

CFLAGS+=-I$(TOSROOT)/apps/breakfast/util
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/globalID
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/i2cDiscover
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/i2cCom
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/i2cPersistentStorage
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/i2cTLVStorage
#CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/i2cSynch
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/i2cADCReader

CFLAGS+=-I$(TOSDIR)/chips/msp430/tlvStorage
CFLAGS+=-I$(TOSDIR)/chips/msp430/msp430xv2/internalFlash
CFLAGS+=-I$(TOSDIR)/chips/msp430/x2xxx/internalFlash

#CLEAN_EXTRA = $(MIGCLASSES)

$(MIGDIR): 
	mkdir -p $(MIGDIR)

$(MIGDIR)/PrintfMsg.py: $(MIGDIR) $(TOSDIR)/lib/printf/printf.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=PrintfMsg $(TOSDIR)/lib/printf/printf.h printf_msg -o $@

$(MIGDIR)/%.py: $(MIGDIR) ctrl_messages.h
	./genMig.sh $(PLATFORM) ctrl_messages.h $@ $(CFLAGS) 

migClasses: $(MIGCLASSES)


include $(MAKERULES)
