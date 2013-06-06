COMPONENT=TestC

TEST_DESC?=\"NO_INFO\"
CFLAGS += -DTEST_DESC=$(TEST_DESC)

##test settings: packet generation rate, flush size, packet
# length
##delay for ms before starting to send
TEST_STARTUP_DELAY ?= \(60UL*1024UL\)
CFLAGS += -DTEST_STARTUP_DELAY=$(TEST_STARTUP_DELAY)
##wai
TEST_IPI ?= \(60UL*1024UL\)
CFLAGS += -DTEST_IPI=$(TEST_IPI)
TEST_RANDOMIZE ?= \(10UL*1024UL\)
CFLAGS += -DTEST_RANDOMIZE=$(TEST_RANDOMIZE)
TEST_DESTINATION ?= AM_BROADCAST_ADDR
CFLAGS += -DTEST_DESTINATION=$(TEST_DESTINATION)
SEND_THRESHOLD ?= 1
CFLAGS += -DSEND_THRESHOLD=$(SEND_THRESHOLD) 
PAYLOAD_LEN ?= 50
CFLAGS += -DPAYLOAD_LEN=$(PAYLOAD_LEN) 
TEST_TRANSMIT ?= 0
CFLAGS += -DTEST_TRANSMIT=$(TEST_TRANSMIT)

SCHEDULED_TEST ?= 0
CFLAGS += -DSCHEDULED_TEST=$(SCHEDULED_TEST)
TEST_FRAME_RANGE ?= 1
CFLAGS += -DTEST_FRAME_RANGE=$(TEST_FRAME_RANGE)
TEST_FRAME_BASE ?= 500
CFLAGS += -DTEST_FRAME_BASE=$(TEST_FRAME_BASE)

##RRB settings
RRB_BW ?= 1
CFLAGS += -DRRB_BW=$(RRB_BW)

##Common Scheduler settings
CX_MASTER ?=1
CFLAGS += -DCX_MASTER=$(CX_MASTER)
CX_STATIC_SCHEDULE ?= 0
CFLAGS += -DCX_STATIC_SCHEDULE=$(CX_STATIC_SCHEDULE)
#Cycle len in frames
CX_DEFAULT_CYCLE_LENGTH ?= 500
CFLAGS +=-DCX_DEFAULT_CYCLE_LENGTH=$(CX_DEFAULT_CYCLE_LENGTH)
#slot len in frames
CX_DEFAULT_SLOT_LENGTH ?= 20
CFLAGS +=-DCX_DEFAULT_SLOT_LENGTH=$(CX_DEFAULT_SLOT_LENGTH)
#MAX_SLOTS is the *total* number of active slots ever permitted.
CX_MAX_SLOTS ?= 20
CFLAGS += -DCX_MAX_SLOTS=$(CX_MAX_SLOTS)
#CX_DEFAULT_MAX_DEPTH is the initially-advertised maxDepth in the
# network.
CX_DEFAULT_MAX_DEPTH ?= 8
CFLAGS +=-DCX_DEFAULT_MAX_DEPTH=$(CX_DEFAULT_MAX_DEPTH)

##Dynamic scheduler settings (when CX_STATIC_SCHEDULE=0)
#EVICTION_THRESHOLD: how many cycles must elapse without hearing from
# a node before it is removed from the schedule. 0 = never evict.
EVICTION_THRESHOLD ?= 0
CFLAGS += -DEVICTION_THRESHOLD=$(EVICTION_THRESHOLD)
#FREE_TIMEOUT: how many cycles after a node has been evicted before a
# slot is advertised as vacant.
FREE_TIMEOUT ?= 3
CFLAGS += -DFREE_TIMEOUT=$(FREE_TIMEOUT)
#MAX_VACANT is the number of vacant slots (available to
# be claimed) which the root announces per cycle.
MAX_VACANT ?= 5
CFLAGS += -DMAX_VACANT=$(MAX_VACANT)

#MAX_ASSIGNMENTS: max # of assignments issued in a single assignment
# message. Must be >0, >1 only matters if multiple slots can be
# assigned to a single node.
MAX_ASSIGNMENTS?=5
CFLAGS += -DMAX_ASSIGNMENTS=$(MAX_ASSIGNMENTS)

#MAX_FREED: max # of freed slots announced in a single schedule.
MAX_FREED?=5
CFLAGS += -DMAX_FREED=$(MAX_FREED)

#Static scheduler settings
#CX_ACTIVE_SLOTS_STATIC: fix the # of active slots.
CX_ACTIVE_SLOTS_STATIC ?= 60
CFLAGS += -DCX_ACTIVE_SLOTS_STATIC=$(CX_ACTIVE_SLOTS_STATIC)

#radio settings
SNRX_SCOOT?=0
CFLAGS += -DSNRX_SCOOT=$(SNRX_SCOOT)
EARLY_WAKEUP?=0
CFLAGS += -DEARLY_WAKEUP=$(EARLY_WAKEUP)

#NB: length field is 8 bits: so if we are using FEC, we need to make
# sure that the total packet length is less than this.
CFLAGS += -DRF1A_FEC_ENABLED=1
#0x8D: 0 dbm
CFLAGS += -DPATABLE0_SETTING=0x8D
CFLAGS += -DTOSH_DATA_LENGTH=109
CFLAGS += -DCX_SELF_RETX=1

CX_RADIOSTATS ?= 0
CFLAGS += -DCX_RADIOSTATS=$(CX_RADIOSTATS)

#Debug levels
DL_LINKQUEUE ?= DL_WARN
DL_RADIOSTATS ?= DL_WARN
DL_NETWORK ?= DL_WARN

ENABLE_PRINTF ?= 1
CFLAGS += -DENABLE_PRINTF=$(ENABLE_PRINTF)
CFLAGS += -DDL_LINK=DL_INFO
CFLAGS += -DDL_LINKQUEUE=$(DL_NETWORK)
CFLAGS += -DDL_NETWORK=$(DL_NETWORK)
CFLAGS += -DDL_SCHED=DL_INFO
CFLAGS += -DDL_SKEW=DL_DEBUG
CFLAGS += -DDL_SKEW_APPLY=DL_INFO
CFLAGS += -DDL_TRANSPORT=DL_WARN
CFLAGS += -DDL_AM=DL_INFO
CFLAGS += -DDL_test=DL_INFO
CFLAGS += -DDL_RADIOSTATS=$(DL_NETWORK)
CFLAGS += -DDL_ROUTING=DL_WARN

#timer/clock config
PFLAGS+=-DMSP430XV2_DCO_CONFIG=MSP430XV2_DCO_32MHz_RSEL6
CFLAGS+=-DXT2_SMCLK

##Link layer timing settings
##set base length of frame in 32K/6.5M scale. 
#CFLAGS += -DFRAMELEN_32K=2048UL
#CFLAGS += -DFRAMELEN_6_5M=406250UL
##Multiply base by FRAMELEN_*CX_SCALE_TIME to get real frame length.
## Larger numbers -> more idle time between radio usage, but lower
## available throughput.
CFLAGS += -DCX_SCALE_TIME=1
##scaling factor applied to nominal minimum prep time: increasing this 
# will force the radio to start preparing radio early. So, larger
# values -> higher duty cycles but looser timing requirements.
#CFLAGS += -DSETUP_SLACK_RATIO=8UL
##set default wait time in 6.5M ticks: 7800 ~= 1.2 ms
#CFLAGS += -DRX_DEFAULT_WAIT=7800UL

##GPIO debug settings
#P1.1: frame boundary
#P1.2: rx/tx
#P1.3: wakeup
#P2.4: gdo (SFD sent/received)
#toggle P1.1 at every used frame boundary
CFLAGS += -DLINK_DEBUG_FRAME_BOUNDARIES=1
#buggy: forces a MARK event at every frame
CFLAGS += -DMARK_ALL_FRAMES=0
#Set P1.3 at wakeup, clear at sleep
CFLAGS += -DLINK_DEBUG_WAKEUP=0

##Test settings: for disabling specific features (probably won't be
## used)
##disable CRC-checking (always pass)
CFLAGS += -DDUMMY_CRC=0
#toggle skew correction
CFLAGS += -DCX_ENABLE_SKEW_CORRECTION=1
#1 = suppress assignments from root (forces slaves to re-request)
CFLAGS += -DTEST_RESELECT=0
#0 = do not timestamp packets
CFLAGS +=-DENABLE_TIMESTAMPING=1
#0 = use TOS_NODE_ID as amAddr (1=check TLV for global ID, use 2 LSB)
CFLAGS += -DAM_ID_FROM_FLASH=0
#initialize the upper word of the 32-bit counters to this value (for
# testing rollover behavior)
#CFLAGS +=-DTC_INIT_UPPER=0xff00
#Disable XT2 duty-cycling (e.g. for validating 32K timer)
#CFLAGS +=-DENABLE_XT2_DC=0

##include paths
CFLAGS += -I$(TOSDIR)/lib/serialprintf
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

include $(MAKERULES)
