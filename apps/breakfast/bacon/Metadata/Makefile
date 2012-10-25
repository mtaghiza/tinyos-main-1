COMPONENT=MetadataAppC
BUILD_EXTRA_DEPS = TestMsg.py PrintfMsg.py

CFLAGS += -DNEW_PRINTF_SEMANTICS
CFLAGS += -I$(TOSDIR)/lib/printf

TestMsg.py: ctrl_messages.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=TestPacket ctrl_messages.h test_msg -o $@

PrintfMsg.py: $(TOSDIR)/lib/printf/printf.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=PrintfMsg $(TOSDIR)/lib/printf/printf.h printf_msg -o $@

include $(MAKERULES)
