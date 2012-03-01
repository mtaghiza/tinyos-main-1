COMPONENT=TestAppC

TEST_CHANNEL?=64
CFLAGS+=-DTEST_CHANNEL=$(TEST_CHANNEL)

TEST_POWER_INDEX?=0
CFLAGS+=-DTEST_POWER_INDEX=$(TEST_POWER_INDEX)

RETX_DELAY?=6000
CFLAGS+=-DRETX_DELAY=$(RETX_DELAY)

##verify that contents written to txfifo match
##note that these are on the critical tx path, so they limit
## RETX_DELAY to around 6000 ticks
#CFLAGS+=-DDEBUG_TXFIFO_P
#CFLAGS+=-DDEBUG_TX_P

#CFLAGS+=-DDEBUG_RX
#CFLAGS+=-DDEBUG_RX_1
#CFLAGS+=-DDEBUG_RX_2
#CFLAGS+=-DDEBUG_RX_3
#CFLAGS+=-DDEBUG_SET_RX_BUFFER
#CFLAGS+=-DDEBUG_RX_4

##P1.1 hpl.send
##P2.4 completeSend
CFLAGS+=-DDEBUG_TX

#CFLAGS+=-DDEBUG_CCA

##P1.4 
##startSend_
#CFLAGS+=-DDEBUG_TX_6
##interrupt
CFLAGS+=-DDEBUG_TX_7

##P1.3
##spinforvalid
#CFLAGS+=-DDEBUG_TX_1
##SFD
#CFLAGS+=-DDEBUG_TX_2
##Scheduler.run_task
#CFLAGS+=-DDEBUG_TASK
##completeSend.STX
CFLAGS+=-DDEBUG_TX_8

##P1.2
##completeSend.wait
#CFLAGS+=-DDEBUG_TX_3
##startTransmission_
#CFLAGS+=-DDEBUG_TX_4
##completeSend.STX
#CFLAGS+=-DDEBUG_TX_5

PFLAGS += -I$(TOSDIR)/lib/serialprintf
PFLAGS += -I$(TOSDIR)/lib/rf1a-cx/flood
PFLAGS += -I$(TOSDIR)/lib/rf1a-cx/interfaces
PFLAGS += -I$(TOSDIR)/lib/rf1a-cx
PFLAGS += -I$(TOSDIR)/lib/rf1a-delayedSend
CFLAGS += -I../../util

#16mhz mclk, 32 mhz dco
PFLAGS+=-DMSP430XV2_DCO_CONFIG=MSP430XV2_DCO_32MHz_RSEL6

CFLAGS+=-DXT2_SMCLK


include $(MAKERULES)
