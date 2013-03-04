COMPONENT=LeafAppC


CFLAGS +=-DADC_NUM_CHANNELS=9

#CFLAGS += -DNEW_PRINTF_SEMANTICS
#CFLAGS += -I$(TOSDIR)/lib/printf
#CFLAGS += -I$(TOSDIR)/lib/serial
#CFLAGS +=-DTOSH_DATA_LENGTH=140

CFLAGS+=-DSINGLE_RECORD_READ=1

CFLAGS += -I../ToastSampler
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

CFLAGS+=-DRF1A_FEC_ENABLED=1
CFLAGS+=-DINCLUDE_RELIABLE_BURST=0
CFLAGS+=-DINCLUDE_UNRELIABLE_BURST=1
CFLAGS+=-DINCLUDE_SCOPED_FLOOD=0

CFLAGS += -I$(TOSDIR)/lib/rf1a-tdma
CFLAGS += -I$(TOSDIR)/lib/rf1a-tdma/ieee154
CFLAGS += -I$(TOSDIR)/lib/rf1a-tdma/timer
CFLAGS += -I$(TOSDIR)/lib/rf1a-tdma/schedule
CFLAGS += -I$(TOSDIR)/lib/rf1a-tdma/link
CFLAGS += -I$(TOSDIR)/lib/rf1a-tdma/tdma
CFLAGS += -I$(TOSDIR)/lib/rf1a-tdma/network
CFLAGS += -I$(TOSDIR)/lib/rf1a-tdma/network/flood
CFLAGS += -I$(TOSDIR)/lib/rf1a-tdma/network/scopedFlood
CFLAGS += -I$(TOSDIR)/lib/rf1a-tdma/transport
CFLAGS += -I$(TOSDIR)/lib/rf1a-tdma/transport/simpleFlood
CFLAGS += -I$(TOSDIR)/lib/rf1a-tdma/transport/nsfUnreliableBurst
CFLAGS += -I$(TOSDIR)/lib/rf1a-tdma/dispatch
CFLAGS += -I$(TOSDIR)/lib/rf1a-tdma/packet
CFLAGS += -I$(TOSDIR)/lib/rf1a-tdma/routing
CFLAGS += -I$(TOSDIR)/lib/rf1a-tdma/am

#16mhz mclk, 32 mhz dco
PFLAGS+=-DMSP430XV2_DCO_CONFIG=MSP430XV2_DCO_32MHz_RSEL6

CFLAGS+=-DXT2_SMCLK

include $(MAKERULES)
