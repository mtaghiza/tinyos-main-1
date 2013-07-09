generic configuration GlobalAMSenderC(am_id_t AMId){
  provides {
    interface AMSend;
    interface Packet;
    interface AMPacket;
    interface PacketAcknowledgements as Acks;
  }
}

implementation {
  components new AMQueueEntryP(AMId) as AMQueueEntryP;
  components GlobalAMQueueP as AMQueueP, 
    ActiveMessageC;

  AMQueueEntryP.Send -> AMQueueP.Send[unique(UQ_GLOBAL_SEND)];
  AMQueueEntryP.AMPacket -> ActiveMessageC;
  
  AMSend = AMQueueEntryP;
  Packet = ActiveMessageC;
  AMPacket = ActiveMessageC;
  Acks = ActiveMessageC;
}

