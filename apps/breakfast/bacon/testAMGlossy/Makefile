COMPONENT=TestSenderAppC

#defaults
FLOOD_INTERVAL?=5120

PFLAGS += -I$(TOSDIR)/lib/serialprintf
PFLAGS += -I$(TOSDIR)/lib/rf1a-delayedSend
PFLAGS += -I$(TOSDIR)/lib/rf1a-glossy
CFLAGS += -I../concxmit-redux
CFLAGS += -I../../util

#16mhz mclk, 32 mhz dco
PFLAGS+=-DMSP430XV2_DCO_CONFIG=MSP430XV2_DCO_32MHz_RSEL6


CFLAGS+=-DFLOOD_INTERVAL=$(FLOOD_INTERVAL)

include $(MAKERULES)
