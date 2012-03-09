COMPONENT=TestAppC

TEST_CHANNEL?=64
CFLAGS+=-DTEST_CHANNEL=$(TEST_CHANNEL)

TEST_POWER_INDEX?=0
CFLAGS+=-DTEST_POWER_INDEX=$(TEST_POWER_INDEX)

CX_FLOOD_RETX_DELAY?=2000
CFLAGS+=-DCX_FLOOD_RETX_DELAY=$(CX_FLOOD_RETX_DELAY)

CX_FLOOD_RADIO_START_SLACK?=10
CFLAGS+=-DCX_FLOOD_RADIO_START_SLACK=$(CX_FLOOD_RADIO_START_SLACK)

SEND_PERIOD?=1
CFLAGS+=-DSEND_PERIOD=$(SEND_PERIOD)

CX_FLOOD_FAILSAFE_LIMIT?=128
CFLAGS+=-DCX_FLOOD_FAILSAFE_LIMIT=$(CX_FLOOD_FAILSAFE_LIMIT)

##32khz ticks
## at 125kbps, test packet payload is 1.8 ms, 2.6 ms including
## preamble and forwarding
## So, framelen should be roughly 58 + (84*num_hops) + a few ticks of
## slack so that next user can get their affairs in order prior to
## their frame start.
CX_FLOOD_DEFAULT_FRAMELEN?=300
CFLAGS+=-DCX_FLOOD_DEFAULT_FRAMELEN=$(CX_FLOOD_DEFAULT_FRAMELEN)

##1 + max number of nodes (one frame needed for announcement)
CX_FLOOD_DEFAULT_NUMFRAMES?=5
CFLAGS+=-DCX_FLOOD_DEFAULT_NUMFRAMES=$(CX_FLOOD_DEFAULT_NUMFRAMES)

##ms
## must be greater than (frameLen >>5) * numFrames
CX_FLOOD_DEFAULT_PERIOD?=256
CFLAGS+=-DCX_FLOOD_DEFAULT_PERIOD=$(CX_FLOOD_DEFAULT_PERIOD)

##p1.2 sfd(gdo): "ground truth" of offset between senders
##p1.1 STX: how closely do two forwarders synchronize their actions?
CFLAGS+=-DCX_FLOOD_TIMING_PINS

##p1.4 high from synch to data send done, used for seeing how stable
##  frame starts are.
##p1.3 high during announcement transmission from root.
#CFLAGS+=-DCX_FLOOD_TIMING_PINS_FRAMING

##p1.4 end-of-packet interrupt, used for jitter measurements
##p1.3 high from start of announcement to root's data frame
CFLAGS+=-DCX_FLOOD_TIMING_PINS_FWD

##P1.1 rf1aPhy.receiveData
##P1.2 sfd(gdo)
##P1.3 floodP.receive
##P1.4 rf1aphy.send -> sendReady
#CFLAGS+=-DDEBUG_CX_FLOOD_FWD


##P1.1 rf1aphysical signals receive -> setReceiveBuffer start
#CFLAGS+=-DDEBUG_RX_4
##P1.3 CXRf1aFloodP.receive
##P1.4 startSend_
#CFLAGS+=-DDEBUG_TX_6


##P1.2: sfd (gdo)
##P1.3: PrepareSendAlarm.fired  (clear at sendDone OR if no data
##      pending)
##P1.4: SendAlarm.fired (clear at sendDone)
#CFLAGS+=-DDEBUG_CX_FLOOD

##P1.1: 
##preparesend alarm start/end 
#CFLAGS+=-DDEBUG_CX_FLOOD_1
##radio power
#CFLAGS+=-DDEBUG_CX_FLOOD_2
##framestarted
#CFLAGS+=-DDEBUG_CX_FLOOD_3

##print src/sn/type of packets sent/received
#CFLAGS+=-DDEBUG_CX_FLOOD_P_PACKET
##print timer info
#CFLAGS+=-DDEBUG_CX_FLOOD_P_TIMERS

##print state transitions that enter an error state 
##P2.4: error state entered
CFLAGS+=-DDEBUG_CX_FLOOD_P_STATE_ERROR

##print state transitions
#CFLAGS+=-DDEBUG_CX_FLOOD_P_STATE
##print function entry/general debug info
#CFLAGS+=-DDEBUG_CX_FLOOD_P

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
#CFLAGS+=-DDEBUG_TX

#CFLAGS+=-DDEBUG_CCA

##P1.4 
##startSend_
#CFLAGS+=-DDEBUG_TX_6
##interrupt
#CFLAGS+=-DDEBUG_TX_7
##TXFIFO write
#CFLAGS+=-DDEBUG_TX_9

##P1.3
##spinforvalid
#CFLAGS+=-DDEBUG_TX_1
##SFD
#CFLAGS+=-DDEBUG_TX_2
##Scheduler.run_task
#CFLAGS+=-DDEBUG_TASK
##completeSend.STX
#CFLAGS+=-DDEBUG_TX_8

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
