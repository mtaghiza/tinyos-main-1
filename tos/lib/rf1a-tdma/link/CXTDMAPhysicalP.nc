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
  enum{
    M_TYPE = 0xf0,

    //split control states
    M_SPLITCONTROL = 0x00,
    S_OFF = 0x00,
    S_STARTING = 0x01,
    S_STOPPING = 0x02,
    
    //mid-frame states:
    // Following frame-prep, we should be in one of these states.
    M_MIDFRAME = 0x10,
    S_INACTIVE = 0x10,
    S_IDLE = 0x11,
    S_RX_PRESTART = 0x12,
    S_TX_PRESTART = 0x13,
    
    //RX intermediate states
    M_RX = 0x20,
    S_RX_START = 0x20,
    S_RX_READY = 0x21,
    S_RX_WAIT = 0x22,
    S_RX_RECEIVING = 0x23,
    S_RX_CLEANUP = 0x24,

    //TX intermediate states
    M_TX = 0x30, 
    S_TX_START = 0x30,
    S_TX_READY = 0x31,
    S_TX_WAIT = 0x32,
    S_TX_TRANSMITTING = 0x33,
    S_TX_CLEANUP = 0x34,
    
    M_ERROR = 0xf0,
    S_ERROR_0 = 0xf0,
    S_ERROR_1 = 0xf1,
    S_ERROR_2 = 0xf2,
    S_ERROR_3 = 0xf3,
    S_ERROR_4 = 0xf4,
    S_ERROR_5 = 0xf5,
    S_ERROR_6 = 0xf6,
    S_ERROR_7 = 0xf7,
    S_ERROR_8 = 0xf8,
    S_ERROR_9 = 0xf9,
    S_ERROR_a = 0xfa,
    S_ERROR_b = 0xfb,
    S_ERROR_c = 0xfc,
    S_ERROR_d = 0xfd,
    S_ERROR_e = 0xfe,
    S_ERROR_f = 0xff,
  };
  
  //Internal state vars
  uint8_t state = S_OFF;
  
  //externally-facing state vars
  uint16_t frameNum;

  //Current radio settings
  uint8_t s_sr = SCHED_INIT_SYMBOLRATE;
  uint8_t s_channel = TEST_CHANNEL;

  //other schedule settings
  uint32_t s_totalFrames;
  uint8_t s_sri = 0xff;
  uint32_t s_frameLen;
  uint32_t s_fwCheckLen;
  bool s_isSynched = FALSE;


  //Split control vars
  bool stopPending = FALSE;
  
  //Utility functions
  void setState(uint8_t s){
    //once we enter error state, reject transitions
    if ((state & M_TYPE) != M_ERROR){
      state = s;
    }
  }

  void stopAlarms(){
    call PrepareFrameStartAlarm.stop();
    call FrameStartAlarm.stop();
    call FrameWaitAlarm.stop();
  }

  //SplitControl operations
  command error_t SplitControl.start(){
    if (state == S_OFF){
      error_t err = call Resource.request();
      if (err == SUCCESS){
        setState(S_STARTING);
      }
      return err;
    }else{
      return EOFF;
    }
  }

  event void Resource.granted(){
    if (state == S_STARTING){
      //NB: Phy impl starts the radio in IDLE
      setState(S_IDLE);
      signal SplitControl.startDone(SUCCESS);
    }else{
      setState(S_ERROR_0);
    }
  }
  
  command error_t SplitControl.stop(){ 
    switch(state){
      case S_OFF:
        return EALREADY;
      default:
        if (stopPending){
          return EBUSY;
        }else{
          stopPending = TRUE;
          return SUCCESS;
        }
    }
  }


  async event void SynchCapture.captured(uint16_t time){}
  async event void PrepareFrameStartAlarm.fired(){}
  async event void FrameWaitAlarm.fired(){}
  async event void FrameStartAlarm.fired(){}


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
  
  error_t checkSetSchedule(){
    switch(state){
      case S_IDLE:
      case S_INACTIVE:
        return SUCCESS;
      case S_OFF:
        return EOFF;
      default:
        return ERETRY;
    }
  }

  command error_t TDMAPhySchedule.setSchedule(uint32_t startAt,
      uint16_t atFrameNum, uint16_t totalFrames, uint8_t symbolRate, 
      uint8_t channel, bool isSynched){
    error_t err = checkSetSchedule();
    if (err != SUCCESS){
      return err;
    }
    atomic{
      uint32_t pfsStartAt;
      uint32_t delta;
      uint8_t last_sr = s_sr;
      uint8_t last_channel = s_channel;
      s_totalFrames = totalFrames;
      s_sr = symbolRate;
      s_sri = srIndex(s_sr);
      s_frameLen = frameLens[s_sri];
      s_fwCheckLen = fwCheckLens[s_sri];

      stopAlarms();
      call SynchCapture.disable();

      //not synched: set the frame wait timeout to 2x frame len
      if (!isSynched){
        s_frameLen *= 10;
        s_fwCheckLen = 2*s_frameLen;
      }

      //while target frameStart is in the past
      // - add 1 to target frameNum, add framelen to target frameStart
      //TODO: fix issue with PFS_SLACK causing numbers to wrap
      pfsStartAt = startAt - PFS_SLACK ;
      while (pfsStartAt < call PrepareFrameStartAlarm.getNow()){
        pfsStartAt += s_frameLen;
        atFrameNum = (atFrameNum + 1)%(s_totalFrames);
      }

      //now that target is in the future: 
      //  - set frameNum to target framenum - 1 (so that pfs counts to
      //    correct frame num when it fires).
      if (atFrameNum == 0){
        frameNum = s_totalFrames;
      }else{
        frameNum = atFrameNum - 1;
      }
      //  - set base and delta to arbitrary values s.t. base +delta =
      //    target frame start
      delta = call PrepareFrameStartAlarm.getNow();
      call PrepareFrameStartAlarm.startAt(pfsStartAt-delta,
        delta);
      call FrameStartAlarm.startAt(pfsStartAt-delta,
        delta + PFS_SLACK);
      s_isSynched = isSynched;

      //If channel or symbol rate changes, need to reconfigure
      //  radio.
      if (s_sr != last_sr || s_channel != last_channel){
        call Rf1aPhysical.reconfigure();
      }
    }

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
