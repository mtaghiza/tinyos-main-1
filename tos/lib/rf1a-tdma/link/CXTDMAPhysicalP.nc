/**
 * Implementation of protocol-independent TDMA.
 *  - Duty cycling
 *  - request data at frame start
 */
 #include "CXTDMA.h"
 #include "CXTDMADebug.h"
 #include "CXTDMADispatchDebug.h"
 #include "SchedulerDebug.h"
 #include "TimingConstants.h"
 #include "Msp430Timer.h"
 #include "decodeError.h"

module CXTDMAPhysicalP {
  provides interface SplitControl;
  provides interface CXTDMA;
  provides interface TDMAPhySchedule;
  provides interface FrameStarted;

  provides interface Rf1aConfigure;
  uses interface Rf1aConfigure as SubRf1aConfigure[uint8_t sr];

  uses interface HplMsp430Rf1aIf;
  uses interface Resource;
  uses interface Rf1aPhysical;
  uses interface Rf1aPhysicalMetadata;
  uses interface Rf1aStatus;

  uses interface Rf1aPacket;
  //needed to set metadata fields of received packets
  uses interface Packet;
  uses interface CXPacket;
  uses interface CXPacketMetadata;

  uses interface Alarm<TMicro, uint32_t> as PrepareFrameStartAlarm;
  uses interface Alarm<TMicro, uint32_t> as FrameStartAlarm;
  uses interface Alarm<TMicro, uint32_t> as FrameWaitAlarm;
  uses interface GpioCapture as SynchCapture;

  uses interface Rf1aDumpConfig;
  uses interface StateTiming;
} implementation {
  //Current radio settings
  uint8_t s_sr;
  uint8_t s_channel;

  async event void SynchCapture.captured(uint16_t time){}
  async event void PrepareFrameStartAlarm.fired(){}
  async event void FrameWaitAlarm.fired(){}
  async event void FrameStartAlarm.fired(){}

  command error_t SplitControl.start(){ return FAIL;}
  command error_t SplitControl.stop(){ return FAIL;}
  event void Resource.granted(){}

  async event bool Rf1aPhysical.getPacket(uint8_t** buffer, 
      uint8_t* len){return FALSE;}
  async event void Rf1aPhysical.receiveDone (uint8_t* buffer,
                                             unsigned int count,
                                             int result) {}
  async event void Rf1aPhysical.sendDone (uint8_t* buffer, 
      uint8_t len, int result) { }
  async event uint8_t Rf1aPhysical.getChannelToUse(){
    return s_channel;
  }
  async event void Rf1aPhysical.frameStarted () { }
  async event void Rf1aPhysical.carrierSense () { }
  async event void Rf1aPhysical.receiveStarted (unsigned int length) { }
  async event void Rf1aPhysical.receiveBufferFilled (uint8_t* buffer,
                                                     unsigned int count) { }
  async event void Rf1aPhysical.clearChannel () { }
  async event void Rf1aPhysical.released () { }

  async event bool Rf1aPhysical.idleModeRx () { return FALSE; }

  async command uint32_t TDMAPhySchedule.getNow(){
    return call FrameStartAlarm.getNow();
  }

  command error_t TDMAPhySchedule.setSchedule(uint32_t startAt,
      uint16_t atFrameNum, uint16_t totalFrames, uint8_t symbolRate, 
      uint8_t channel, bool isSynched){
    return FAIL;
  }

  async command const rf1a_config_t* Rf1aConfigure.getConfiguration(){
    printf_SCHED_SR("Get configuration: %u\r\n", s_sr);
    return call SubRf1aConfigure.getConfiguration[s_sr]();
  }

  async command void Rf1aConfigure.preConfigure (){ }
  async command void Rf1aConfigure.postConfigure (){ }
  async command void Rf1aConfigure.preUnconfigure (){}
  async command void Rf1aConfigure.postUnconfigure (){}

  default async command void SubRf1aConfigure.preConfigure [uint8_t client](){ }
  default async command void SubRf1aConfigure.postConfigure [uint8_t client](){}
  default async command void SubRf1aConfigure.preUnconfigure [uint8_t client](){}
  default async command void SubRf1aConfigure.postUnconfigure [uint8_t client](){}


  default async command const rf1a_config_t* SubRf1aConfigure.getConfiguration[uint8_t client] ()
  {
    printf("CXTDMAPhysicalP: Unknown sr requested: %u\r\n", client);
    return call SubRf1aConfigure.getConfiguration[1]();
  }}
