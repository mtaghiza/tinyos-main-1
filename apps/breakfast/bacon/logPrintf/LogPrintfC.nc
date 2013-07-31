
 #include "LogPrintf.h"
generic configuration LogPrintfC(volume_id_t VOLUME_ID, 
    bool circular) {
  provides interface LogPrintf;
} implementation {
  components new LogStorageC(VOLUME_ID, circular);

  components new LogPrintfP();
  LogPrintf = LogPrintfP;

  LogPrintfP.LogWrite -> LogStorageC;

  components new QueueC(log_printf_t*, 2);
  components new PoolC(log_printf_t, 2);

  LogPrintfP.Queue -> QueueC;
  LogPrintfP.Pool -> PoolC;
}
