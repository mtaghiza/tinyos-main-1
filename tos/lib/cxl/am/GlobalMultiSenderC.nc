configuration GlobalMultiSenderC {
  provides interface AMSend[am_id_t id];
} implementation {
  components new MultiSenderP();
  components GlobalAMQueueP as AMQueueP;
  components ActiveMessageC as ActiveMessageC;
  MultiSenderP.Send 
    -> AMQueueP.Send[unique(UQ_GLOBAL_SEND)];
  MultiSenderP.AMPacket -> ActiveMessageC;
  AMSend = MultiSenderP;
}

