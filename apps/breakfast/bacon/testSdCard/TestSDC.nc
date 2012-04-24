
configuration TestSDC {

} implementation {
  #if USE_FS == 1
  components BenchmarkSDP as TestSDP;
  #else
  components BenchmarkNoFSP as TestSDP;
  #endif

  components MainC;
  TestSDP.Boot -> MainC;

  components LedsC;
  TestSDP.Leds -> LedsC;

  components new TimerMilliC() as Timer;
  TestSDP.Timer -> Timer;

  #if USE_FS || SYNC_SD == 1
  components SDCardSyncC as SDCardC;
  #else
  components SDCardC as SDCardC;
  #endif
  TestSDP.Resource -> SDCardC;
  TestSDP.SDCard -> SDCardC;
  
/*
  components new Msp430UsciSpiB0C() as Msp430SpiB0C;
  TestSDP.SpiResource -> Msp430SpiB0C;
  TestSDP.SpiByte -> Msp430SpiB0C;

  components HplMsp430GeneralIOC as GeneralIOC;
  components new Msp430GpioC() as CS;
  CS -> GeneralIOC.Port11;
  TestSDP.CS -> CS;
*/

  components CounterMilli32C;
  TestSDP.MilliCounter -> CounterMilli32C;

  components Msp430Counter32khzC;
  TestSDP.Msp430Counter32khz -> Msp430Counter32khzC;

  /* Serial interface */
  components StdOutC;
  TestSDP.SerialControl -> StdOutC;
  TestSDP.StdOut -> StdOutC;


}
