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

  components LedsC;
  TestP.Leds -> LedsC;
}
