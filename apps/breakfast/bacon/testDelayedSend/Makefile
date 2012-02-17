COMPONENT=TestSenderAppC

PFLAGS += -I$(TOSDIR)/lib/serialprintf
PFLAGS += -I$(TOSDIR)/lib/rf1a-delayedSend
CFLAGS += -I../concxmit-redux

#32mhz mclk
PFLAGS+=-DMSP430XV2_DCO_CONFIG=MSP430XV2_DCO_64MHz_RSEL7

include $(MAKERULES)
