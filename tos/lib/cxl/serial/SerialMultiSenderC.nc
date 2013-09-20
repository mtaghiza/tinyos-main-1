configuration SerialMultiSenderC {
  provides interface AMSend[am_id_t id];
} implementation {
  components new MultiSenderP();
  components SerialAMQueueP as AMQueueP;
  components SerialActiveMessageC as ActiveMessageC;
  MultiSenderP.Send 
    -> AMQueueP.Send[unique(UQ_SERIALQUEUE_SEND)];
  MultiSenderP.AMPacket -> ActiveMessageC;
  AMSend = MultiSenderP;

}
