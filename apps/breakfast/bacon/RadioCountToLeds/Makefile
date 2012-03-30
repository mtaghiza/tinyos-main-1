COMPONENT=RadioCountToLedsAppC
BUILD_EXTRA_DEPS = RadioCountMsg.py RadioCountMsg.class
CLEAN_EXTRA = RadioCountMsg.py RadioCountMsg.class RadioCountMsg.java

#dbm patable0
# -30 0x03
# -12 0x25
#  -6 0x2D
#   0 0x8D
#  10 0xC3
# max 0xC0
PAYLOAD_LEN?=20
TEST_POWER?=0xC3
TEST_CHANNEL?=0
TEST_IPI?=256
TEST_IPI_RAND?=64
IS_SENDER?=1

CFLAGS+=-DTOSH_DATA_LENGTH=60
CFLAGS+=-DPAYLOAD_LEN=$(PAYLOAD_LEN)
CFLAGS+=-I$(TOSDIR)/lib/serialprintf

CFLAGS+=-DTEST_CHANNEL=$(TEST_CHANNEL)
CFLAGS+=-DTEST_POWER=$(TEST_POWER)
CFLAGS+=-DIS_SENDER=$(IS_SENDER)
CFLAGS+=-DTEST_IPI=$(TEST_IPI)
CFLAGS+=-DTEST_IPI_RAND=$(TEST_IPI_RAND)

RadioCountMsg.py: RadioCountToLeds.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=RadioCountMsg RadioCountToLeds.h radio_count_msg -o $@

RadioCountMsg.class: RadioCountMsg.java
	javac RadioCountMsg.java

RadioCountMsg.java: RadioCountToLeds.h
	mig java -target=$(PLATFORM) $(CFLAGS) -java-classname=RadioCountMsg RadioCountToLeds.h radio_count_msg -o $@


include $(MAKERULES)

