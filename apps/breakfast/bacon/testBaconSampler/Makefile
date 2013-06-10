COMPONENT=TestAppC

#CFLAGS += -DNEW_PRINTF_SEMANTICS
#CFLAGS += -I$(TOSDIR)/lib/printf
#CFLAGS += -I$(TOSDIR)/lib/serial
CFLAGS +=-DTOSH_DATA_LENGTH=140

CFLAGS+=-DSINGLE_RECORD_READ=1

CFLAGS += -I../BaconSampler
CFLAGS += -I../settingsStorage
CFLAGS += -I../RebootCounter

BACON_SAMPLER_HIGH?=0
CFLAGS+=-DBACON_SAMPLER_HIGH=$(BACON_SAMPLER_HIGH)

CFLAGS+=-I$(TOSROOT)/apps/breakfast/util
CFLAGS+=-I$(TOSROOT)/apps/breakfast/bacon/autoPush
CFLAGS+=-I$(TOSDIR)/chips/msp430/tlvStorage

include $(MAKERULES)
