COMPONENT=InitTestbedAppC
CFLAGS+=-I$(TOSDIR)/lib/serialprintf
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/globalID
CFLAGS+= -I$(TOSROOT)/apps/breakfast/bacon/settingsStorage
CFLAGS +=-I$(TOSROOT)/apps/breakfast/bacon/RebootCounter
CFLAGS+=-I$(TOSDIR)/chips/msp430/tlvStorage


AUTOMATIC?=1
CFLAGS+=-DAUTOMATIC=$(AUTOMATIC)
include $(MAKERULES)
