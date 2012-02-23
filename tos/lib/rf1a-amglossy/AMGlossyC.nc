//TODO: AM ID for glossy should be fixed, it should encapsulate an
//entire other AM header. So, this should be singleton and should
//just dispatch to relevant client as needed? hm.

generic configuration AMGlossyC(am_id_t AMId){
  provides interface AMSend;
  provides interface AMPacket;
  provides interface Receive;
} implementation {
  components new DelayedAMSenderC(AMId);
  components new AMReceiverC(AMId);
  components new AlarmMicro16C();
  
  components Rf1aActiveMessageC;

  components new AMGlossyP();
  AMGlossyP.DelayedSend -> DelayedAMSenderC.DelayedSend;
  AMGlossyP.SubAMSend -> DelayedAMSenderC.AMSend;
  AMGlossyP.SendNotifier -> DelayedAMSenderC.SendNotifier;
  AMGlossyP.SubReceive -> AMReceiverC;
  AMGlossyP.SubAMPacket -> Rf1aActiveMessageC;
  AMGlossyP.Alarm -> AlarmMicro16C;
  
  //TODO: if there are multiple AMGlossyC's, they'll all be wired to the
  //  same rf1aphysical interface. 
  //  Kept Rf1aCoreInterrupt the same for consistency (since they both
  //  basically just expose the core interrupts)
  AMGlossyP.Rf1aPhysical -> Rf1aActiveMessageC;
  AMGlossyP.Rf1aCoreInterrupt -> Rf1aActiveMessageC;

  AMSend = AMGlossyP.AMSend;
  AMPacket = AMGlossyP.AMPacket;
  Receive = AMGlossyP.Receive;
  
}
