#include <stdio.h>
configuration TestSenderAppC {
} implementation {
  components SerialPrintfC;

  components TestSenderP as TestP;
  components new TimerMilliC();
  components MainC;

  TestP.Boot -> MainC;
  TestP.Timer -> TimerMilliC;
  components new AMGlossyC(0xDD);  

  TestP.RadioSend -> AMGlossyC;
  TestP.Receive -> AMGlossyC;

  components ActiveMessageC;
  TestP.SplitControl -> ActiveMessageC;

  components Rf1aActiveMessageC;
  TestP.Rf1aPhysical -> Rf1aActiveMessageC;
  TestP.HplMsp430Rf1aIf -> Rf1aActiveMessageC;

  //Switch at compile time if desired
  components GlossyRf1aSettingsC as Rf1aSettings;

  Rf1aActiveMessageC.Rf1aConfigure -> Rf1aSettings;

  components LedsC;
  TestP.Leds -> LedsC;

  components PlatformSerialC;
  TestP.SerialControl -> PlatformSerialC;
  TestP.UartStream -> PlatformSerialC;
  
  components Rf1aDumpConfigC;
  TestP.Rf1aConfigure -> Rf1aSettings;
  TestP.Rf1aDumpConfig -> Rf1aDumpConfigC;
}
