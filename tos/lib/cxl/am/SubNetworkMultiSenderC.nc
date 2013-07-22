configuration SubNetworkMultiSenderC {
  provides interface AMSend[am_id_t id];
} implementation {
  components new MultiSenderP();
  components SubNetworkAMQueueP as AMQueueP;
  components ActiveMessageC as ActiveMessageC;
  MultiSenderP.Send 
    -> AMQueueP.Send[unique(UQ_SUBNETWORK_SEND)];
  MultiSenderP.AMPacket -> ActiveMessageC;
  AMSend = MultiSenderP;
}

