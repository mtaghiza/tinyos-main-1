
 #include "requestQueue.h"
configuration TestAppC{
} implementation {
  components MainC;
  components TestP;
  
  components PlatformSerialC;
  components SerialPrintfC;

  TestP.Boot -> MainC;
  TestP.UartStream -> PlatformSerialC;
  
  components new PoolC(cx_request_t, 4);
  components new PriorityQueueC(cx_request_t*, 4);
  
  TestP.Pool -> PoolC;
  TestP.Queue -> PriorityQueueC;
  PriorityQueueC.Compare -> TestP;
}
