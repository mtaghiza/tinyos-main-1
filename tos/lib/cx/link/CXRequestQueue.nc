
 #include "message.h"
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
  
  //N.B.: generally, if you need something sent based on a previous
  // capture event, you should request the send from the *handled
  // event. Otherwise, there's a possibility that the timer will be
  // shut off at the completion of the *handled event.
  command error_t requestSend(uint32_t baseFrame, 
    int32_t frameOffset, 
    bool useMicro, uint32_t microRef, 
    nx_uint32_t* tsLoc,
    message_t* msg);

  event void sendHandled(error_t error, 
    uint32_t atFrame, uint32_t microRef, 
    message_t* msg);

  command error_t requestSleep(uint32_t baseFrame, 
    int32_t frameOffset);
  event void sleepHandled(error_t error, uint32_t atFrame);

  command error_t requestWakeup(uint32_t baseFrame, 
    int32_t frameOffset);
  event void wakeupHandled(error_t error, uint32_t atFrame);

  command error_t requestFrameShift(uint32_t baseFrame, 
    int32_t frameOffset, int32_t frameShift);
  event void frameShiftHandled(error_t error, uint32_t atFrame);


}
