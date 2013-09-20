configuration TestAppC{
} implementation {
  components MainC;
  components TestP;
  components new TimerMilliC();
  components LedsC;
  #if RAW_PRINTF == 1
  components SerialPrintfC;
  #else
  components SerialStartC;
  components PrintfC;
  #endif

  TestP.Boot -> MainC;
  TestP.Leds -> LedsC;
  TestP.Timer -> TimerMilliC;
}
