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
  #if RF1A_BAUD == 500000
  components GlossyRf1aSettings500KC as Rf1aSettings;
  #elif RF1A_BAUD == 250000 
  components GlossyRf1aSettings250KC as Rf1aSettings;
  #elif RF1A_BAUD == 125000
  components GlossyRf1aSettings125KC as Rf1aSettings;
  #elif RF1A_BAUD == 1200
  components GlossyRf1aSettings1P2KC as Rf1aSettings;
  #else 
  #warning RF1A_BAUD not defined or recognized, using 250K
  components GlossyRf1aSettings250KC as Rf1aSettings;
  #endif

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
