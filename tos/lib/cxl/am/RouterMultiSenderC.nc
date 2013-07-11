configuration RouterMultiSenderC {
  provides interface AMSend[am_id_t id];
} implementation {
  components new MultiSenderP();
  components RouterAMQueueP as AMQueueP;
  components ActiveMessageC as ActiveMessageC;
  MultiSenderP.Send 
    -> AMQueueP.Send[unique(UQ_ROUTER_SEND)];
  MultiSenderP.AMPacket -> ActiveMessageC;
  AMSend = MultiSenderP;
}


