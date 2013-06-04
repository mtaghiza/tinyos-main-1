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
CFLAGS += -DPATABLE0_SETTING=0x8D
CFLAGS += -DTOSH_DATA_LENGTH=109
CFLAGS += -DCX_SELF_RETX=1

#Debug levels
CFLAGS += -DDL_LINK=DL_ERROR
CFLAGS += -DDL_LINKQUEUE=DL_ERROR
CFLAGS += -DDL_NETWORK=DL_ERROR
CFLAGS += -DDL_SCHED=DL_ERROR
CFLAGS += -DDL_SKEW=DL_ERROR
CFLAGS += -DDL_SKEW_APPLY=DL_ERROR
CFLAGS += -DDL_TRANSPORT=DL_ERROR
CFLAGS += -DDL_AM=DL_ERROR
CFLAGS += -DDL_test=DL_ERROR
CFLAGS += -DDL_RADIOSTATS=DL_ERROR

CFLAGS += -I$(TOSDIR)/lib/priorityQueue
CFLAGS += -I$(TOSDIR)/lib/cx
CFLAGS += -I$(TOSDIR)/lib/cx/scheduler
CFLAGS += -I$(TOSDIR)/lib/cx/network
CFLAGS += -I$(TOSDIR)/lib/cx/transport
CFLAGS += -I$(TOSDIR)/lib/cx/link
CFLAGS += -I$(TOSDIR)/lib/cx/physical
CFLAGS += -I$(TOSDIR)/lib/cx/packet
CFLAGS += -I$(TOSDIR)/lib/cx/am
CFLAGS += -I$(TOSDIR)/lib/cx/routing
CFLAGS += -I$(TOSDIR)/lib/cx/debug
CFLAGS += -I$(TOSDIR)/lib/rf1a-tdma/timer
CFLAGS += -I$(TOSROOT)/apps/breakfast/util
CFLAGS += -I$(TOSROOT)/apps/breakfast/util/stackGuard
CFLAGS += -I$(TOSROOT)/apps/breakfast/util/globalID
CFLAGS += -I$(TOSDIR)/chips/msp430/tlvStorage

#16mhz mclk, 32 mhz dco
PFLAGS+=-DMSP430XV2_DCO_CONFIG=MSP430XV2_DCO_32MHz_RSEL6

CFLAGS+=-DXT2_SMCLK

include $(MAKERULES)
