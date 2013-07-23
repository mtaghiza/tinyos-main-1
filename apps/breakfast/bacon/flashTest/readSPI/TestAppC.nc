configuration TestAppC{
} implementation {

  components SerialPrintfC;
  components SerialStartC;

  components MainC;
  components PlatformSerialC;
  TestP.UartStream -> PlatformSerialC;

  components TestP;
  TestP.Boot -> MainC;

  components Stm25pSpiC;
  TestP.Stm25pSpi -> Stm25pSpiC;

  MainC.SoftwareInit -> Stm25pSpiC.Init;
  TestP.Resource -> Stm25pSpiC.Resource;
}
