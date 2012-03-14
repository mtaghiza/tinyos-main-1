module TDMASchedulerP{
  provides interface SplitControl;
  provides interface CXTDMA;

  uses interface SplitControl as SubSplitControl;
  uses interface CXTDMA as SubCXTDMA;

  uses interface AMPacket; 
  uses interface CXPacket; 
  uses interface Packet; 
  uses interface Rf1aPacket; 
  uses interface Ieee154Packet;
} implementation {
  command error_t SplitControl.start(){
    return call SubSplitControl.start();
  }

  command error_t SplitControl.stop(){
    return call SubSplitControl.stop();
  }

  event void SubSplitControl.startDone(error_t error){
    signal SplitControl.startDone(error);
  }

  event void SubSplitControl.stopDone(error_t error){
    signal SplitControl.stopDone(error);
  }

  command error_t CXTDMA.setSchedule(uint32_t startAt,
      uint16_t atFrameNum, uint32_t frameLen, 
      uint32_t fwCheckLen, uint16_t activeFrames, 
      uint16_t inactiveFrames){
    return call SubCXTDMA.setSchedule(startAt, atFrameNum, frameLen,
      fwCheckLen, activeFrames, inactiveFrames);
  }

  async command uint32_t CXTDMA.getNow(){
    return call SubCXTDMA.getNow();
  }

  async event rf1a_offmode_t SubCXTDMA.frameType(uint16_t frameNum){
    return signal CXTDMA.frameType(frameNum);
  }

  async event bool SubCXTDMA.getPacket(message_t** msg, uint8_t* len){
    return signal CXTDMA.getPacket(msg, len);
  }

  async event void SubCXTDMA.sendDone(error_t error){
    signal CXTDMA.sendDone(error);
  }

  async event message_t* SubCXTDMA.receive(message_t* msg, 
      uint8_t len){
    return signal CXTDMA.receive(msg, len);
  }

  async event void SubCXTDMA.frameStarted(uint32_t startTime){
    signal CXTDMA.frameStarted(startTime);
  }



}
