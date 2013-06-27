
 #include "ping.h"
configuration PingC {
  uses interface Pool<message_t>;
} implementation {
  components new AMReceiverC(AM_PING_MSG);
  components new AMSenderC(AM_PONG_MSG);
  
  components RebootCounterC;
  components LocalTime32khzC;
  components LocalTimeMilliC;

  components PingP;
  PingP.Receive -> AMReceiverC;
  PingP.AMSend -> AMSenderC;
  PingP.AMPacket -> AMSenderC;
  PingP.Packet -> AMSenderC;
  
  PingP.RebootCounter -> RebootCounterC;
  PingP.LocalTimeMilli -> LocalTimeMilliC;
  PingP.LocalTime32k -> LocalTime32khzC;

  PingP.Pool = Pool;
}
