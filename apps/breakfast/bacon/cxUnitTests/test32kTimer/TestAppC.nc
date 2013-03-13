configuration TestAppC{
} implementation {
  components MainC;
  components TestP;
  
  components PlatformSerialC;
  components SerialPrintfC;

  TestP.Boot -> MainC;
  TestP.UartStream -> PlatformSerialC;
  
  components new Timer32khzC();
  TestP.Timer -> Timer32khzC;
}
