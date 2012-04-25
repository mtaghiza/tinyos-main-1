configuration SDLoggerC{
  provides interface SDLogger;
  provides interface SplitControl as WriteControl;
} implementation {
  components SDLoggerP;
  components SDCardSyncC as SDCardC;

  SDLoggerP.Resource -> SDCardC;
  SDLoggerP.SDCard -> SDCardC;

  SDLogger = SDLoggerP;
  WriteControl = SDLoggerP;

  components MainC;
  SDLoggerP.Boot -> MainC.Boot;
}
