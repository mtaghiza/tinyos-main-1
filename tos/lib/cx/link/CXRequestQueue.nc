
 #include "message.h"
interface CXRequestQueue{

  //return the next available frame, according to this layer. A return
  //value of 0 indicates "no valid next frame, try again later"
  //This can happen, for instance, if we were not assigned any slots
  //in the current schedule.
  command uint32_t nextFrame(bool isTX);
  
  //specifying duration of 0 means "use whatever default is
  //appropriate" e.g. if we are not synched, the scheduler will set
  //this to some huge value.
  command error_t requestReceive(uint32_t baseFrame, 
    int32_t frameOffset, 
    bool useMicro, uint32_t microRef,
    uint32_t duration, 
    void* md, message_t* msg);

  event void receiveHandled(error_t error, 
    uint32_t atFrame, uint32_t reqFrame, 
    bool didReceive, 
    uint32_t microRef, uint32_t t32kRef,
    void* md, message_t* msg); 
  
  //N.B.: generally, if you need something sent based on a previous
  // capture event, you should request the send from the *handled
  // event. Otherwise, there's a possibility that the timer will be
  // shut off at the completion of the *handled event.
  command error_t requestSend(uint32_t baseFrame, 
    int32_t frameOffset, 
    bool useMicro, uint32_t microRef, 
    nx_uint32_t* tsLoc,
    void* md, message_t* msg);

  event void sendHandled(error_t error, 
    uint32_t atFrame, uint32_t reqFrame, 
    uint32_t microRef, uint32_t t32kRef,
    void* md, message_t* msg);

  command error_t requestSleep(uint32_t baseFrame, 
    int32_t frameOffset);
  event void sleepHandled(error_t error, uint32_t atFrame, 
    uint32_t reqFrame);

  command error_t requestWakeup(uint32_t baseFrame, 
    int32_t frameOffset);
  event void wakeupHandled(error_t error, uint32_t atFrame, 
    uint32_t reqFrame);

  command error_t requestFrameShift(uint32_t baseFrame, 
    int32_t frameOffset, int32_t frameShift);
  event void frameShiftHandled(error_t error, uint32_t atFrame,
    uint32_t reqFrame);


}
