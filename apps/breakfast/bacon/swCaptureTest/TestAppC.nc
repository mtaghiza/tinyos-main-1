configuration TestAppC{
} implementation {
  components MainC;
  components LedsC;
  components SerialPrintfC;
  components TestP;
  components PlatformSerialC;
  components new Msp430SWCaptureC(); 
   
  TestP.Boot -> MainC.Boot;
  TestP.Leds -> LedsC;
  TestP.UartControl -> PlatformSerialC.StdControl;
  TestP.UartStream -> PlatformSerialC.UartStream;
  TestP.SWCapture -> Msp430SWCaptureC;
}
