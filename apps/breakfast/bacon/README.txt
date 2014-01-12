

Directory Contents
==================

Active Code
-----------
genBinaries.sh : compile Leaf, Router, and BaseStation applications
  and put the resulting firmware images into the directory used by the
  Labeler UI tool.

BaconSampler : components for sampling bacon on-board sensors. See
  BaconSampler/README.txt for more details.

Basestation : Application for bacon node acting as bridge between PC
  and bacon network. See Basestation/README.txt for more details.

Leaf : Application for bacon nodes deployed in the field with Toast
  boards. See Leaf/README.txt for more details.

Metadata : Application for node when it is used by Labeler UI tool to
  configure hardware and assign barcodes. See Metadata/README.txt for
  more details.

RebootCounter : Sub-application that increments a reboot counter in
  mote internal flash on reboot and provides Get access to this field.

Router : Application for bacon node acting as router.  See
  Router/README.txt for more details.

ToastSampler : Sub-application for identifying Toast boards and
  reading their data. See ToastSampler/README.txt for more details.

autoPush : Sub-application that handles sending outstanding data from
  the log and handling recovery requests. See autoPush/README.txt for
  more details.

cxCommon : Makefile containing role-independent radio and debug
  settings for Leaf, Router, and Basestation applications.
  cxCommon/Makefile should be included in any application using CX to
  ensure that paths and symbols are defined and given sensible
  defaults.

settingsStorage : Utility for reading/writing key value pairs to mote
  internal flash. Add the enclosed dummy directory to the build path
  prior to the main directory if you need to build a binary that
  exposes a SettingsStorageC, but doesn't use the internal flash (e.g.
  for space reasons).




Potentially-useful code not in general use:
-----------------
connectivityTest : application and scripts for collecting and
  analyzing testbed connectivity. See connectivityTest/README.txt for
  more details.

cxUnitTests : applications designed for interactive testing of each
  layer of the CX networking stack while it was being written. 
  cxUnitTests/cxl is for the most recent iteration of the CX stack.

cxlTestbed : applications and scripts for testbed usage of the most
  recent iteration of the CX stack. See cxlTestbed/README.txt for more
  details.

iar : notes for connecting a JTAG debugger to a bacon mote.

initTestbed : load barcodes onto testbed nodes in bulk. See
  initTestbed/README.txt for more details.

logPrintf : sub-application used to record arbitrary strings to the
  mote log storage. Used in debugging only.  Usage is to use sprintf
  to put debug contents into a byte array, then use this component to
  log it to flash.

rebooter : components that enable either randomly-timed reboots or
  reboots triggered via UART messages. Used for testing behavior when
  nodes are unstable. 

sdCard : drivers and modifications for implementing log storage on an
  external SD card. Not sure what state this code is in.

testRadio :  used for visual indication of range (blinking LEDs) and
  serial logging for phy/PRR results. install.sh controls the radio
  settings used to set up the motes (see usage notes). The output is
  via unbuffered serial printf (so you can log it via picocom, for
  instance).  The scripts directory contained herein contains usage
  information for parsing/plotting the data.

testRadioTelos : see testRadio. This is set up specifically for the
  telos/cc2420-specific features.

testSdCard : application for testing FATFS and other performance of SD
  card. Not sure what state this code is in.

testToast : interactive test application for toast discovery and usage
  of individual I2C commands. Might be helpful in understanding
  communication between bacon and toast.

Obsolete/Unused Code:
---------------------
BaconCollect : first effort at a full system for doing data collection
  with the Bacon and Toast boards.

BaconRadioTest : used for preliminary testing of bacon and amplifier
  performance.

CC1190DriverTest : used for verifying that the radio amplifier is
  correctly toggled on/off by driver.

Ping : sub-application which receives AM messages and responds to
  sender.

RadioCountToLeds : first crack at an application to check radio PRR
  and phy performance.

TestDs1825Ecomote : Test porting onewire code to the pre-bacon cc430
  platform from the PeoplePower surf platform.

TestMemoryOsian : copy of PeoplePower external flash test code. Used
  when testing flash driver modifications for larger chips.

adcTest : used while experimenting with settings for ADC12 and voltage
  reference (REF) module on the cc430, results incorporated into
  BaconSampler code.

clockPower : tests for verifying entry/exit into low power modes and
  current consumption of various parts of the clock and timer
  subsystems.

concxmit-am : test application for early experiments in concurrent
  tranmission. See concxmit-am/README.txt

concxmit-redux : code for collecting physical layer measurements
  of concurrent transmissions and analyzing the resulting data.  

cxActiveMessage : application and processing for testbed usage of an
  old version of the CX stack. This was used for the paper "Forwarder
  Selection in Multi-transmitter Networks" from DCOSS 2013.

cxAnalysis : Scripts to generate figures and aggregated data from logs
  resulting from use of cxActiveMessage. Used for "Forwarder Selection
  in Multi-transmitter Networks" from DCOSS 2013.

cxTestbed : application and processing for obsolete version of CX
  stack.

externalPhotoTest : testing/development of photodiode. This was
  written for the bacon v.1, pin assignments are different in the
  current hardware.

fastToggle :  testing PWM function of timer modules

flashTest : used when modifying the flash driver for the bacon
  platform.

i2c : used when developing the i2c driver code.

minLeaf : test code used during leaf dev. 

photoTest : test photo sensor driver on bacon v.2

radioTest : old test code for doing simple radio connectivity tests.

rf1aManual : test code for stepping through rf1a driver and verifying
  individual steps used in CX worked correctly.

sniffer : radio sniffer for an earlier version of radio stack. 

swCaptureTest : attempt to do software-triggered timer capture.

tdmaAODVTest : early test application for performing forwarder
  selection.

tdmaFloodTest : early test application for multi-transmitter floods

tdmaScopedFloodTest : early test application for self-limiting
  multi-transmitter floods

tdmaTest : test application for early CX stack

testAMGlossy : test application for early CX stack

testAdc12DMA : test of DMA + ADC12 code for cc430

testAutoPush : test application for auto-push/recovery over serial AM
  stack.

testBSL : test app for cc430-bsl 

testBaconClock : c apps for testing clock calibration/DCO settings

testBaconSampler : Test of bacon sampler + auto-push over serial AM
  stack.

testCRC : experimenting with hardware CRC module driver

testCXFlood : test/debug of early CX stack flooding behavior

testDelayedSend : test/debug of TXFIFO pre-loading

testFlash : test/debug of external flash driver

testFlashTimeout : test/debug of automatic shut-down timeout on
  external flash.

testInterruptStatus : pin output for identifying when interrupts are
  disabled/enabled with logic analyzer

testLogNotify : terminal/serial test and debug of LogNotify component

testPWM : experimentation/verification of pulse-generation (used to
  set delays between transmitters in concxmit-redux)

testPrintf : experiments with unbuffered raw serial printf, buffered
  raw serial printf, and AM serial printf

testRecordStorage : interactive application for developing/debugging
  the single-record-read implementation of log storage.

testSettingsStorage : test application for SettingsStorageConfigurator
  communication 

testToastSampler : unit test for ToastSampler sub-application.

testbed : application and scripts for running older version of CX
  stack on the testbed and visualizing behavior.

thermistorTest : test of high-level read interface for on-board
  thermistor

timerBug : Attempt to reproduce and report bug with timer code to core
  tinyos. This application triggers an error condition in the telos
  timer module.

uav : attempt at writing a high-frequency ADC sampler/logger. SD card
  could not keep up with the sampling rate, and this project got
  abandoned.
