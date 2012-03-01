COMPONENT=RadioCountToLedsAppC
BUILD_EXTRA_DEPS = RadioCountMsg.py RadioCountMsg.class
CLEAN_EXTRA = RadioCountMsg.py RadioCountMsg.class RadioCountMsg.java

PAYLOAD_LEN?=20
DELAY?=TRUE

CFLAGS+=-DTOSH_DATA_LENGTH=60
CFLAGS+=-DPAYLOAD_LEN=$(PAYLOAD_LEN)
CFLAGS+=-DDELAY=$(DELAY)
CFLAGS+=-I$(TOSDIR)/lib/serialprintf
CFLAGS+=-I$(TOSDIR)/lib/rf1a-cx
CFLAGS+=-I$(TOSDIR)/lib/rf1a-delayedSend

CFLAGS+=-DDEBUG_TXFIFO_P

#CFLAGS+=-DDEBUG_RX

#CFLAGS+=-DDEBUG_RX
#CFLAGS+=-DDEBUG_RX_1
#CFLAGS+=-DDEBUG_RX_2
#CFLAGS+=-DDEBUG_RX_3
#CFLAGS+=-DDEBUG_SET_RX_BUFFER
#CFLAGS+=-DDEBUG_RX_4

CFLAGS+=-DDEBUG_TX_P

##1.1: Rf1aPhysical.send
##1.4: sendFragment_
##2.4: DelayedSend.completeSend
CFLAGS+=-DDEBUG_TX

#CFLAGS+=-DDEBUG_CCA

##P1.3
##spinforvalid
#CFLAGS+=-DDEBUG_TX_1
##SFD
CFLAGS+=-DDEBUG_TX_2
##Scheduler.run_task
#CFLAGS+=-DDEBUG_TASK

##P1.2
##completeSend.wait
#CFLAGS+=-DDEBUG_TX_3
##startTransmission_
#CFLAGS+=-DDEBUG_TX_4
##completeSend.STX
#CFLAGS+=-DDEBUG_TX_5
##writeBurstRegister
#CFLAGS+=-DDEBUG_TX_6
##need_repost_ds
#CFLAGS+=-DDEBUG_TX_7
##need_signal_ds
#CFLAGS+=-DDEBUG_TX_8
##auto-complete (strobe issued)
CFLAGS+=-DDEBUG_TX_9

RadioCountMsg.py: RadioCountToLeds.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=RadioCountMsg RadioCountToLeds.h radio_count_msg -o $@

RadioCountMsg.class: RadioCountMsg.java
	javac RadioCountMsg.java

RadioCountMsg.java: RadioCountToLeds.h
	mig java -target=$(PLATFORM) $(CFLAGS) -java-classname=RadioCountMsg RadioCountToLeds.h radio_count_msg -o $@


include $(MAKERULES)

