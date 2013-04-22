configuration ScheduledAMSendC{
  provides interface ScheduledAMSend[uint8_t clientId];
  uses interface AMSend as SubAMSend[uint8_t clientId];
} implementation {
  components ScheduledAMSendP;
  ScheduledAMSend = ScheduledAMSendP;
  SubAMSend = ScheduledAMSendP;
  
  components CXPacketMetadataC;
  ScheduledAMSendP.CXPacketMetadata -> CXPacketMetadataC;
}
