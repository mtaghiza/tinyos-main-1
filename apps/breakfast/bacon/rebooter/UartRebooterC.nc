configuration UartRebooterC{
} implementation {
  components MainC;
  components UartRebooterP;
  components PlatformSerialC;

  UartRebooterP.SerialControl -> PlatformSerialC;
  UartRebooterP.UartStream -> PlatformSerialC;
  UartRebooterP.Boot -> MainC;

}
