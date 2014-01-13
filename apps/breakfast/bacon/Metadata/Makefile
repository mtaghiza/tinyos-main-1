COMPONENT=MetadataAppC
MIGDIR = $(TOSROOT)/apps/breakfast/tools/Life/tools/mig

BAUDRATE?=115200
CFLAGS+=-DTOS_DEFAULT_BAUDRATE=$(BAUDRATE)

##couldn't entice Make to run this command...
#grep 'msg{' ctrl_messages.h | awk '{print $3}' | tr -d '{' | sed -re 's,(_|^)([a-z]),\u\2,g' -e 's,^,$(MIGDIR)/,g' -e 's,$,.py,g'
MIGCLASSES = $(MIGDIR)/ReadIvCmdMsg.py $(MIGDIR)/ReadIvResponseMsg.py $(MIGDIR)/ReadMfrIdCmdMsg.py $(MIGDIR)/ReadMfrIdResponseMsg.py $(MIGDIR)/ReadAdcCCmdMsg.py $(MIGDIR)/ReadAdcCResponseMsg.py $(MIGDIR)/ReadBaconBarcodeIdCmdMsg.py $(MIGDIR)/ReadBaconBarcodeIdResponseMsg.py $(MIGDIR)/WriteBaconBarcodeIdCmdMsg.py $(MIGDIR)/WriteBaconBarcodeIdResponseMsg.py $(MIGDIR)/ReadToastBarcodeIdCmdMsg.py $(MIGDIR)/ReadToastBarcodeIdResponseMsg.py $(MIGDIR)/WriteBaconVersionCmdMsg.py $(MIGDIR)/WriteBaconVersionResponseMsg.py $(MIGDIR)/ReadBaconVersionCmdMsg.py $(MIGDIR)/ReadBaconVersionResponseMsg.py $(MIGDIR)/WriteToastBarcodeIdCmdMsg.py $(MIGDIR)/WriteToastBarcodeIdResponseMsg.py $(MIGDIR)/ReadToastAssignmentsCmdMsg.py $(MIGDIR)/ReadToastAssignmentsResponseMsg.py $(MIGDIR)/WriteToastAssignmentsCmdMsg.py $(MIGDIR)/WriteToastAssignmentsResponseMsg.py $(MIGDIR)/WriteToastVersionCmdMsg.py $(MIGDIR)/WriteToastVersionResponseMsg.py $(MIGDIR)/ReadToastVersionCmdMsg.py $(MIGDIR)/ReadToastVersionResponseMsg.py $(MIGDIR)/ReadAnalogSensorCmdMsg.py $(MIGDIR)/ReadAnalogSensorResponseMsg.py $(MIGDIR)/ScanBusCmdMsg.py $(MIGDIR)/ScanBusResponseMsg.py $(MIGDIR)/PingCmdMsg.py $(MIGDIR)/PingResponseMsg.py $(MIGDIR)/ResetBaconCmdMsg.py $(MIGDIR)/ResetBaconResponseMsg.py $(MIGDIR)/SetBusPowerCmdMsg.py $(MIGDIR)/SetBusPowerResponseMsg.py $(MIGDIR)/ReadBaconTlvCmdMsg.py $(MIGDIR)/ReadBaconTlvResponseMsg.py $(MIGDIR)/ReadToastTlvCmdMsg.py $(MIGDIR)/ReadToastTlvResponseMsg.py $(MIGDIR)/WriteBaconTlvCmdMsg.py $(MIGDIR)/WriteBaconTlvResponseMsg.py $(MIGDIR)/WriteToastTlvCmdMsg.py $(MIGDIR)/WriteToastTlvResponseMsg.py $(MIGDIR)/DeleteBaconTlvEntryCmdMsg.py $(MIGDIR)/DeleteBaconTlvEntryResponseMsg.py $(MIGDIR)/DeleteToastTlvEntryCmdMsg.py $(MIGDIR)/DeleteToastTlvEntryResponseMsg.py $(MIGDIR)/AddBaconTlvEntryCmdMsg.py $(MIGDIR)/AddBaconTlvEntryResponseMsg.py $(MIGDIR)/AddToastTlvEntryCmdMsg.py $(MIGDIR)/AddToastTlvEntryResponseMsg.py $(MIGDIR)/ReadBaconTlvEntryCmdMsg.py $(MIGDIR)/ReadBaconTlvEntryResponseMsg.py $(MIGDIR)/ReadToastTlvEntryCmdMsg.py $(MIGDIR)/ReadToastTlvEntryResponseMsg.py $(MIGDIR)/ReadBaconSensorCmdMsg.py $(MIGDIR)/ReadBaconSensorResponseMsg.py 
MIGCLASSES += $(MIGDIR)/PrintfMsg.py 
MIGCLASSES += $(MIGDIR)/ReadAdcCCmdMsg.py
MIGCLASSES += $(MIGDIR)/ReadAdcCResponseMsg.py

USE_AM_RADIO?=0
CFLAGS += -DUSE_AM_RADIO=$(USE_AM_RADIO)

CFLAGS+=-DADC_NUM_CHANNELS=8
#CFLAGS+=-DSUPPRESS_ADC_OVERFLOW_WARNING

CFLAGS += -DNEW_PRINTF_SEMANTICS
CFLAGS += -I$(TOSDIR)/lib/printf
CFLAGS += -I$(TOSDIR)/lib/serial
#CFLAGS += -I$(TOSDIR)/lib/dualAM
CFLAGS += -Ihandlers
CFLAGS += -I.
CFLAGS +=-DTOSH_DATA_LENGTH=140

CFLAGS+=-I$(TOSROOT)/apps/breakfast/util
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/globalID
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/i2cDiscover
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/i2cCom
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/i2cPersistentStorage
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/i2cTLVStorage
#CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/i2cSynch
CFLAGS+=-I$(TOSROOT)/apps/breakfast/util/i2cADCReader

CFLAGS+=-I$(TOSDIR)/chips/msp430/tlvStorage
CFLAGS+=-I$(TOSDIR)/chips/msp430/msp430xv2/internalFlash
CFLAGS+=-I$(TOSDIR)/chips/msp430/x2xxx/internalFlash

#PFLAGS+=-DMSP430XV2_DCO_CONFIG=MSP430XV2_DCO_32MHz_RSEL6

#CLEAN_EXTRA = $(MIGCLASSES)

$(MIGDIR): 
	mkdir -p $(MIGDIR)

$(MIGDIR)/PrintfMsg.py: $(MIGDIR) $(TOSDIR)/lib/printf/printf.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=PrintfMsg $(TOSDIR)/lib/printf/printf.h printf_msg -o $@

$(MIGDIR)/%.py: $(MIGDIR) ctrl_messages.h
	genMig.sh $(PLATFORM) ctrl_messages.h $@ $(CFLAGS) 

migClasses: $(MIGCLASSES)


include $(MAKERULES)
