#include "concxmit.h"
#include <stdio.h>
//originally (c) people power, adapted for modulation scheme testing on 07/11/11 by doug carlson
configuration TestSenderAppC {
} implementation {
  components SerialPrintfC;

  components TestSenderP as TestP;
  components new TimerMilliC();
  components MainC;

  TestP.Boot -> MainC;
  TestP.Timer -> TimerMilliC;
  
  components new DelayedAMSenderC(CONCXMIT_RADIO_AM_TEST);
  TestP.RadioSend -> DelayedAMSenderC;
  TestP.DelayedSend -> DelayedAMSenderC;

  components ActiveMessageC;
  TestP.SplitControl -> ActiveMessageC;

  components LedsC;
  TestP.Leds -> LedsC;
  
}
