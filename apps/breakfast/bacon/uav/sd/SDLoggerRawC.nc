configuration SDLoggerRawC{
  provides interface SDLogger;
  provides interface SplitControl as WriteControl;
} implementation {
  components SDLoggerRawP as SDLoggerP;
  components SDCardC as SDCardC;

  SDLoggerP.Resource -> SDCardC;
  SDLoggerP.SDCard -> SDCardC;

  SDLogger = SDLoggerP;
  WriteControl = SDLoggerP;

  components MainC;
  SDLoggerP.Boot -> MainC.Boot;
}
