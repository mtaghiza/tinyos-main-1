interface CXRequestQueue{
  command uint32_t nextFrame();

  command error_t requestReceive(uint32_t baseFrame, 
    int32_t frameOffset, 
    bool useMicro, uint32_t microRef,
    uint32_t duration,
    message_t* msg);

  event void receiveHandled(error_t error, 
    uint32_t atFrame, bool didReceive, 
    uint32_t microRef, message_t* msg); 

  command error_t requestSend(uint32_t baseFrame, 
    int32_t frameOffset, 
    bool useMicro, uint32_t microRef,
    message_t* msg);

  event void sendHandled(error_t error, 
    uint32_t atFrame, uint32_t microRef, 
    message_t* msg);

  command error_t requestSleep(uint32_t baseFrame, 
    int32_t frameOffset);
  event void error_t sleepHandled(error_t error, uint32_t atFrame);

  command error_t requestWakeup(uint32_t baseFrame, 
    int32_t frameOffset);
  event void error_t wakeupHandled(error_t error, uint32_t atFrame);


}
