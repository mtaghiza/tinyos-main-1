COMPONENT=TestAppC

CFLAGS +=-DADC_NUM_CHANNELS=8

CFLAGS += -DNEW_PRINTF_SEMANTICS
CFLAGS += -I$(TOSDIR)/lib/printf
CFLAGS += -I$(TOSDIR)/lib/serial
CFLAGS +=-DTOSH_DATA_LENGTH=140

CFLAGS += -I../ToastSampler
CFLAGS += -I../settingsStorage

CFLAGS+=-I$(TOSROOT)/apps/breakfast/util
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/globalID
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/i2cDiscover
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/i2cCom
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/i2cTLVStorage
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/i2cADCReader
CFLAGS+=-I$(TOSROOT)/apps/breakfast/bacon/Metadata

CFLAGS+=-I$(TOSDIR)/chips/msp430/tlvStorage
CFLAGS+=-I$(TOSDIR)/chips/msp430/x2xxx/internalFlash

include $(MAKERULES)
