COMPONENT=LeafAppC

CFLAGS += -I$(TOSROOT)/apps/breakfast/util
CFLAGS+= -DTOSH_DATA_LENGTH=109
CFLAGS+= -DRF1A_FEC_ENABLED=1
CFLAGS += -I../ToastSampler
CFLAGS += -I../BaconSampler
CFLAGS += -I../settingsStorage
CFLAGS += -I../RebootCounter
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/globalID
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/i2cDiscover
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/i2cCom
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/i2cTLVStorage
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/i2cADCReader
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/i2cSynch
CFLAGS+=-I$(TOSROOT)/apps/breakfast/bacon/Metadata
CFLAGS+=-I$(TOSROOT)/apps/breakfast/bacon/autoPush
CFLAGS+=-I$(TOSDIR)/chips/msp430/tlvStorage
CFLAGS += -I../../util/stackGuard
CFLAGS += -I../../util

include $(MAKERULES)
