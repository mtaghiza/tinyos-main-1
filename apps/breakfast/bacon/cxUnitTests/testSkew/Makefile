COMPONENT=TestSkewC

CFLAGS+=-I$(TOSDIR)/lib/serialprintf
CFLAGS += -I$(TOSDIR)/lib/cx/debug
CFLAGS += -I$(TOSDIR)/lib/cx/scheduler
CFLAGS += -I$(TOSDIR)/lib/cx/network

CFLAGS += -I$(TOSROOT)/apps/breakfast/util
CFLAGS += -I$(TOSROOT)/apps/breakfast/util/globalID
CFLAGS += -I$(TOSDIR)/chips/msp430/tlvStorage

CFLAGS += -DDL_SKEW=DL_DEBUG
CFLAGS += -DCX_USE_FP_SKEW_CORRECTION=0

include $(MAKERULES)

