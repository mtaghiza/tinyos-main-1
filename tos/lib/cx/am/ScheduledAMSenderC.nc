
 #include "AM.h"
 #include "ScheduledAM.h"
generic configuration ScheduledAMSenderC(am_id_t AMId){
  provides {
    interface ScheduledAMSend;
    interface Packet;
    interface AMPacket;
    interface PacketAcknowledgements as Acks;
  }
} implementation {
  enum {
    clientId = unique(UQ_SCHEDULED_AM_SENDER),
  };
  components new AMSenderC(AMId) as SenderC;
  
  components ScheduledAMSendC;
  ScheduledAMSend = ScheduledAMSendC.ScheduledAMSend[clientId];
  ScheduledAMSendC.SubAMSend[clientId] -> SenderC.AMSend;

  Packet = SenderC;
  AMPacket = SenderC;
  Acks = SenderC;
}
