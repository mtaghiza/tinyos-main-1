/*
 * Copyright (c) 2014 Johns Hopkins University.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
*/

/** 
 * Sub-send layer below active message impl (and above physical send)
 * to provide flood-based routing/duty cycling.
 *
 * @author Doug Carlson <carlson@cs.jhu.edu>
 */

#include "CX.h"
#include "CXFlood.h"
#include "decodeError.h"

module Rf1aCXFloodP {
  provides interface Send;
  provides interface Receive;
  provides interface SplitControl;
  provides interface PacketAcknowledgements;
  provides interface CXFloodControl;

  uses interface Send as SubSend;
  uses interface Receive as SubReceive;

  uses interface SplitControl as SubSplitControl;
  //should probably roll this into rf1aphysical
  uses interface DelayedSend;
  uses interface Rf1aPhysical;
  uses interface Rf1aCoreInterrupt;
  uses interface HplMsp430Rf1aIf;
  uses interface CXPacket;
  uses interface Packet as LayerPacket;
  uses interface Rf1aPacket;
  uses interface Ieee154Packet;
  uses interface Packet as SubPacket;

  uses interface Pool<message_t> as MessagePool;
  uses interface Queue<message_t*> as MessageQueue;
  uses interface Queue<uint8_t> as LenQueue;

  provides interface GetNow<bool> as GetCCACheck;
  provides interface GetNow<bool> as GetFastReTX;

  //only have this here because we need to pull address out of it,
  //whooops
  //Though: we could actually pull this out of the 15.4 header (same
  //field used)
  uses interface AMPacket;

  uses interface Alarm<TMicro, uint32_t> as SendAlarm;

  //can't do very long periods with 16-bit uS alarm (only up to ~65 ms,
  //  which won't be sufficient for large networks). use 32khz for
  //  prepareSend, start SendAlarm when it fires.
  uses interface Alarm<T32khz, uint16_t> as PrepareSendAlarm;

  uses interface Timer<TMilli> as OnTimer;
  uses interface Timer<TMilli> as OffTimer;

}
implementation {

  //States and state variables
  enum{
    S_OFF   = 0x40,

    ERROR_MASK = 0x80,
    S_ERROR = 0x81,
    S_ERROR_2 = 0x82,
    S_ERROR_3 = 0x83,
    S_ERROR_4 = 0x84,
    S_ERROR_5 = 0x85,
    S_ERROR_6 = 0x86,
    S_ERROR_7 = 0x87,
    S_ERROR_8 = 0x88,
    S_ERROR_9 = 0x89,
    S_ERROR_a = 0x8a,
    S_ERROR_b = 0x8b,
    S_ERROR_c = 0x8c,
    S_ERROR_d = 0x8d,
    S_ERROR_e = 0x8e,
    S_ERROR_f = 0x8f,

    S_ROOT_OFF = 0x10,
    S_ROOT_INACTIVE = 0x11,
    S_ROOT_ANNOUNCE_PREPARE = 0x12,
    S_ROOT_ANNOUNCING = 0x13,
    S_ROOT_IDLE = 0x14,
    S_ROOT_DATA_PREPARE = 0x15,
    S_ROOT_DATA_READY = 0x16,
    S_ROOT_DATA_SENDING = 0x17,
    S_ROOT_RECEIVING = 0x18,
    S_ROOT_FORWARD_PREPARE = 0x19,
    S_ROOT_FORWARD_READY = 0x1a,
    S_ROOT_FORWARDING = 0x1b,
    S_ROOT_STOPPING = 0x1c,

    S_NR_OFF = 0x20,
    S_NR_INACTIVE = 0x21,
    S_NR_IDLE = 0x22,
    S_NR_DATA_PREPARE = 0x23,
    S_NR_DATA_READY = 0x24,
    S_NR_DATA_SENDING = 0x25,
    S_NR_RECEIVING = 0x26,
    S_NR_FORWARD_PREPARE = 0x27,
    S_NR_FORWARD_READY = 0x28,
    S_NR_FORWARDING = 0x29,
    S_NR_STOPPING = 0x2a,

  };

  uint8_t state = S_OFF;
  bool radioOn;

  //scheduling variables
  uint32_t period = CX_FLOOD_DEFAULT_PERIOD;
  uint32_t frameLen = CX_FLOOD_DEFAULT_FRAMELEN;
  uint16_t numFrames = CX_FLOOD_DEFAULT_NUMFRAMES;
  uint16_t claimedFrame = 0;

  //root variables
  message_t announcement_internal;
  message_t* announcement = &announcement_internal;

  //tx variables
  message_t* dataFrame;
  uint8_t dataFrameLen;
  bool dataFrameSent = FALSE;
  error_t sendDoneError;
  uint8_t mySn;

  //rx variables
  uint8_t failsafeCounter = 0;
  bool hasSynched = FALSE;
  bool synchedThisRound = FALSE;
  uint32_t startTime;
  
  //duplicate detection
  am_addr_t lastSrc;
  uint8_t lastSn;

  //Forward declarations
  task void signalStartDoneTask();
  task void signalStopDoneTask();
  task void reportReceivesTask();

  //utility functions
  bool checkState(uint8_t s){
    atomic return (state == s);
  }

  void setState(uint8_t s){
    #ifdef DEBUG_CX_FLOOD_P_STATE
    printf("[%x->%x]\n\r", state, s);
    #endif

    #ifdef DEBUG_CX_FLOOD_P_STATE_ERROR
    if (ERROR_MASK == (s & ERROR_MASK)){
      P2OUT |= BIT4;
      printf("[%x->%x]\n\r", state, s);
    }
    #endif
    atomic state = s;
  }

  /**
   * ROOT_OFF: start radio, start onTimer(periodic), post task to
   *     signal startDone. 
   *   -> ROOT_INACTIVE
   *
   * NR_OFF: same as ROOT_OFF. reset failsafe counter, set hasSynched
   *      to FALSE.
   *   -> NR_INACTIVE
   *
   */
  command error_t SplitControl.start(){ 
    error_t error;
    #ifdef DEBUG_CX_FLOOD_P
    printf("%s: \n\r", __FUNCTION__);
    #endif
    if (checkState(S_ROOT_OFF) || checkState(S_NR_OFF)){
      error = call SubSplitControl.start();
      if (error == SUCCESS){
        call OnTimer.startPeriodic(period);
        if (checkState(S_ROOT_OFF)){
          setState(S_ROOT_INACTIVE);
        } else {
          hasSynched = FALSE;
          failsafeCounter = 0;
          setState(S_NR_INACTIVE);
        }
        //TODO: signal this at the end of the first period for root,
        //      when synch obtained for non-root. signaling it right
        //      now puts it in the way of a lot of critical code.
        post signalStartDoneTask();
      }else{
        setState(S_ERROR);
      }
      return error;
    } else {
      return FAIL;
    }
  }

  /**
   *  All: Stop the onTimer.
   *    + radioOn: do nothing (end of active period will trigger the
   *      stopdone
   *    + ! radioOn: post task to signal stopDone
   *      + S_ROOT_INACTIVE: 
   *        -> S_ROOT_OFF
   *      + S_NR_INACTIVE: 
   *        -> S_NR_OFF
   */
  command error_t SplitControl.stop(){
    #ifdef DEBUG_CX_FLOOD_P
    printf("%s: \n\r", __FUNCTION__);
    #endif
    call OnTimer.stop();
    if (radioOn){
      //nothing extra
      return SUCCESS;
    } else {
      if (checkState(S_ROOT_INACTIVE)){
        setState(S_ROOT_OFF);
      } else if(checkState(S_NR_INACTIVE)){
        setState(S_NR_OFF);
      } else {
        setState(S_ERROR);
        return FAIL;
      }
      post signalStopDoneTask();
      return SUCCESS;
    }
  }
  
  /**
   *  All: 
   *  ROOT_INACTIVE: load announcement frame. start off-timer.
   *    -> ROOT_ANNOUNCE_PREPARE
   * 
   *  NR_INACTIVE: set synchedThisRound to FALSE.
   *    -> NR_IDLE
   */
  event void SubSplitControl.startDone(error_t error){
    #ifdef DEBUG_CX_FLOOD_P
    printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
    #endif
    if (error == SUCCESS){
      #ifdef DEBUG_CX_FLOOD
      P1OUT &= ~BIT3;
      #endif
      #ifdef DEBUG_CX_FLOOD_2
      P1OUT |= BIT1;
      #endif
      #ifdef CX_FLOOD_TIMING_PINS_FRAMING
      P1OUT &= ~BIT4;
      P1OUT &= ~BIT3;
      #endif
      dataFrameSent = FALSE;
      radioOn = TRUE;
      call Rf1aPhysical.setChannel(TEST_CHANNEL);
      call HplMsp430Rf1aIf.writeSinglePATable(POWER_SETTINGS[TEST_POWER_INDEX]);

      //GDO1: 0x07 = RE on CRC OK, FE on read
      //GDO1: 0x06 = RE on synch, FE at end of packet
      call HplMsp430Rf1aIf.writeRegister(IOCFG1, 0x06);
      //falling edge
      call HplMsp430Rf1aIf.setIes(call HplMsp430Rf1aIf.getIes() | BIT1);
      //enable interrupt
      call HplMsp430Rf1aIf.setIe(call HplMsp430Rf1aIf.getIe() | BIT1);
    }

    if (checkState(S_ROOT_INACTIVE)){
      error_t sendError;
      cx_flood_announcement_t* pl;
      #ifdef CX_FLOOD_TIMING_PINS_FRAMING
      P1OUT |= BIT3;
      #endif

      call Rf1aPacket.configureAsData(announcement);
      call AMPacket.setSource(announcement, call AMPacket.address());
      call Ieee154Packet.setPan(announcement, call Ieee154Packet.localPan());
      call AMPacket.setDestination(announcement, AM_BROADCAST_ADDR);
      call CXPacket.setDestination(announcement, AM_BROADCAST_ADDR);

      pl = call LayerPacket.getPayload(announcement,
        sizeof(cx_flood_announcement_t));
      pl -> period = period;
      pl -> frameLen = frameLen;
      pl -> numFrames = numFrames;
      #ifdef DEBUG_CX_FLOOD_P
      printf("<announce p %lu fl %lu nf %u>\n\r", pl->period,
        pl->frameLen, pl->numFrames);
      #endif
      call CXPacket.setType(announcement, CX_TYPE_FLOOD_ANNOUNCEMENT);
      call CXPacket.setSn(announcement, mySn++);
      setState(S_ROOT_ANNOUNCE_PREPARE);
      #ifdef DEBUG_CX_FLOOD_P_PACKET
      printf("A{%u %u %x}\n\r", call CXPacket.source(announcement), 
        call CXPacket.sn(announcement), 
        call CXPacket.type(announcement)); 
      #endif
      sendError = call SubSend.send(announcement,
        sizeof(cx_flood_announcement_t) + sizeof(cx_header_t));
      if (SUCCESS != sendError){
        call OffTimer.stop();
        setState(S_ERROR_b);
      } else {
        lastSrc = call CXPacket.source(announcement);
        lastSn = call CXPacket.sn(announcement);
      }

    } else if (checkState(S_NR_INACTIVE)){
      synchedThisRound = FALSE;
      setState(S_NR_IDLE);

    } else {
      setState(S_ERROR_c);
    }
  }
  
  /**
   *  ROOT_ANNOUNCE_PREPARE: complete send immediately.
   *    -> ANNOUNCING
   *
   *  ROOT_DATA_PREPARE:
   *    -> ROOT_DATA_READY
   * 
   *  ROOT_FORWARD_PREPARE:
   *    -> ROOT_FORWARD_READY
   *
   *  NR_DATA_PREPARE:
   *    -> NR_DATA_READY
   *
   *  NR_FORWARD_PREPARE:
   *    -> NR_FORWARD_READY
   */
  async event void DelayedSend.sendReady(){
//    printf("%s: \n\r", __FUNCTION__);
    if (checkState(S_ROOT_ANNOUNCE_PREPARE)){
      setState(S_ROOT_ANNOUNCING);
      #ifdef CX_FLOOD_TIMING_PINS_FWD
      P1OUT |= BIT3;
      #endif
      call DelayedSend.completeSend();
    } else if (checkState(S_ROOT_DATA_PREPARE)){
      setState(S_ROOT_DATA_READY);
    } else if (checkState(S_ROOT_FORWARD_PREPARE)){
      setState(S_ROOT_FORWARD_READY);
    } else if (checkState(S_NR_DATA_PREPARE)){
      setState(S_NR_DATA_READY);
    } else if (checkState(S_NR_FORWARD_PREPARE)){
      setState(S_NR_FORWARD_READY);
    } else {
      setState(S_ERROR_2);
    }
  }
 
 /**
  *  ANNOUNCING: start PrepareSend alarm.
  *    -> ANNOUNCING
  *
  *  ROOT_IDLE: start Send alarm for retransmission.
  *    -> ROOT_RECEIVING
  *
  *  NR_IDLE: start Send alarm for retransmission.
  *    + claimedFrame and not synchedThisRound: start PrepareSend alarm (pending cancellation
  *      if this is *not* a schedule announcement).
  *    -> NR_RECEIVING
  *
  */
  uint16_t psaBase;
  uint32_t frameStart;
  //Frame start: synch point for entire period
  async event void Rf1aPhysical.frameStarted(){ 
    uint32_t s = call SendAlarm.getNow();
    uint16_t p  = call PrepareSendAlarm.getNow();
    #ifdef DEBUG_CX_FLOOD_3
    P1OUT |= BIT1;
    #endif
    if (checkState(S_ROOT_ANNOUNCING) || 
          (checkState(S_NR_IDLE) && !synchedThisRound)){
      if (claimedFrame > 0){
        #ifdef DEBUG_CX_FLOOD_1
        P1OUT |= BIT1;
        #endif
        frameStart = s;
        psaBase = p;
        //TODO: should correct for time spent being forwarded already.
        call PrepareSendAlarm.startAt(psaBase, (claimedFrame * frameLen)-
          STARTSEND_SLACK_32KHZ);

        //this must be getting interrupted.
//        printf("psa %u -> %u\n\r", psaBase,
//          call PrepareSendAlarm.getAlarm());

//        printf("sa (%lu) %lu\n\r", call PrepareSendAlarm.getNow(), claimedFrame*frameLen -
//          STARTSEND_SLACK_32KHZ);
      }
      startTime = call OnTimer.getNow();
    } 
    if (checkState(S_ROOT_ANNOUNCING)){
      call OffTimer.startOneShot((frameLen >> 5)*numFrames);
    }
    #ifdef DEBUG_CX_FLOOD_3
    P1OUT &= ~BIT1;
    #endif
  }

  async event void Rf1aCoreInterrupt.interrupt (uint16_t iv) { 
    uint32_t isa = call SendAlarm.getNow();
    switch(iv){
      //4: end-of-packet (good CRC): get ready to retransmit it! 
      case 4:
        //don't try to retransmit our own packet
        if (checkState(S_ROOT_ANNOUNCING) 
            || checkState(S_ROOT_DATA_SENDING) 
            || checkState(S_ROOT_FORWARDING) 
            || checkState(S_NR_DATA_SENDING) 
            || checkState(S_NR_FORWARDING)){
    
        } else  if (checkState(S_ROOT_IDLE)){
          call SendAlarm.startAt(isa, CX_FLOOD_RETX_DELAY);
          #ifdef CX_FLOOD_TIMING_PINS_FWD
          P1OUT |= BIT4;
          #endif
          setState(S_ROOT_RECEIVING);
    
        } else if (checkState(S_NR_IDLE)){
          call SendAlarm.startAt(isa, CX_FLOOD_RETX_DELAY);
          #ifdef CX_FLOOD_TIMING_PINS_FWD
          P1OUT |= BIT4;
          #endif
          setState(S_NR_RECEIVING);
    
        } else if (checkState(S_ROOT_INACTIVE) || checkState(S_NR_INACTIVE)){
          //this seems to get hit when we turn the radio on. odd.
        } else {
          setState(S_ERROR_3);
        }
        break;

      default:
        printf("Unused core interrupt: %x\n\r", iv);
        break;
    }
  } 

  /**
   *  ROOT_IDLE + dataPending: load data frame
   *    -> ROOT_DATA_PREPARE
   *
   *  NR_IDLE + data pending: load data frame
   *    -> NR_DATA_PREPARE
   */
  uint32_t psa_fms;
  uint16_t psa_f;
  uint16_t targetXT2;

  async event void PrepareSendAlarm.fired(){
    psa_fms = call OnTimer.getNow();
    psa_f = call PrepareSendAlarm.getNow();

    #ifdef CX_FLOOD_TIMING_PINS_FRAMING
    P1OUT |= BIT4;
    #endif
    #ifdef CX_FLOOD_TIMING_PINS_FWD
    P1OUT &= ~BIT3;
    #endif
    targetXT2 = frameStart + (claimedFrame * frameLen *
      XT2_32KHZ_RATIO)+MYSTERY_OFFSET; 
    call SendAlarm.startAt(frameStart,
      (claimedFrame*frameLen*XT2_32KHZ_RATIO));
    #ifdef DEBUG_CX_FLOOD_P
    printf("%s: \n\r", __FUNCTION__);
    #endif
    #ifdef DEBUG_CX_FLOOD
    P1OUT |= BIT3;
    #endif
    #ifdef DEBUG_CX_FLOOD_1
    P1OUT &= ~BIT1;
    #endif
        
    if (checkState(S_ROOT_IDLE) || checkState(S_NR_IDLE)){
      error_t error;
      if (dataFrame != NULL){
        if (checkState(S_ROOT_IDLE)){
          setState(S_ROOT_DATA_PREPARE);
        } else {
          setState(S_NR_DATA_PREPARE);
        }
        call CXPacket.setSn(dataFrame, mySn++);
        #ifdef DEBUG_CX_FLOOD_P_PACKET
        printf("D{%u %u %x}\n\r", call CXPacket.source(dataFrame), 
          call CXPacket.sn(dataFrame), call CXPacket.type(dataFrame)); 
        #endif
        error = call SubSend.send(dataFrame, dataFrameLen);
        if (SUCCESS != error){
          call SendAlarm.stop();
          setState(S_ERROR_d);
        }else{
          lastSrc = call CXPacket.source(dataFrame);
          lastSn = call CXPacket.sn(dataFrame);
        }
      } else {
        #ifdef DEBUG_CX_FLOOD
        P1OUT &= ~BIT3;
        #endif
        call SendAlarm.stop();
      }

    } else {
      //BUG: observed from S_NR_FORWARDING: perhaps indicating that
      //previous send did not report sendDone OR frames are too small.
      setState(S_ERROR_4);
      call SendAlarm.stop();
    }
  }
  
  /**
   *  ROOT_DATA_READY: complete send.
   *    -> ROOT_DATA_SENDING
   * 
   *  ROOT_FORWARD_READY: complete send.
   *    -> ROOT_FORWARDING
   *
   *  NR_DATA_READY: complete send.
   *    -> NR_DATA_SENDING
   * 
   *  NR_FORWARD_READY: complete send.
   *    -> NR_FORWARDING
   */
  uint16_t saf;
  async event void SendAlarm.fired(){
    #ifdef DEBUG_CX_FLOOD
    P1OUT |= BIT4;
    #endif
    saf = call SendAlarm.getNow();
//    printf("%s: \n\r", __FUNCTION__);
    if (checkState(S_ROOT_DATA_READY)){
      call DelayedSend.completeSend();
      setState(S_ROOT_DATA_SENDING);

    } else if (checkState(S_ROOT_FORWARD_READY)){
      #ifdef CX_FLOOD_TIMING_PINS_FWD
      P1OUT &= ~BIT4;
      #endif
      call DelayedSend.completeSend();
      setState(S_ROOT_FORWARDING);

    } else if (checkState(S_NR_DATA_READY)){
      #ifdef CX_FLOOD_TIMING_PINS_FWD
      P1OUT &= ~BIT4;
      #endif
      call DelayedSend.completeSend();
      setState(S_NR_DATA_SENDING);

    } else if (checkState(S_NR_FORWARD_READY)){
      #ifdef CX_FLOOD_TIMING_PINS_FWD
      P1OUT &= ~BIT4;
      #endif
      call DelayedSend.completeSend();
      setState(S_NR_FORWARDING);

    } else {
      printf("unexpected sendalarm.fired\n\r");
      //TODO: have seen this from S_INACTIVE
      setState(S_ERROR_5);
    }
  }

  /**
   *  ANNOUNCING:
   *    -> ROOT_IDLE
   * 
   *  ROOT_DATA_SENDING: record error for send done report.
   *    -> ROOT_IDLE
   * 
   *  ROOT_FORWARDING:  post report-receive task
   *    -> ROOT_IDLE
   * 
   *  NR_DATA_SENDING: record error for send done report.
   *    -> NR_IDLE
   * 
   *  NR_FORWARDING:  post report-receive task
   *    -> NR_IDLE
   */
  event void SubSend.sendDone(message_t* msg, error_t error){
    #ifdef DEBUG_CX_FLOOD
    P1OUT &= ~(BIT3 | BIT4);
    #endif
//    printf("%s: \n\r ", __FUNCTION__);

    if (checkState(S_ROOT_ANNOUNCING)){
      #ifdef CX_FLOOD_TIMING_PINS_FRAMING
      P1OUT &= ~BIT3;
      #endif
      setState(S_ROOT_IDLE);
    }else if (checkState(S_ROOT_DATA_SENDING)){
      #ifdef CX_FLOOD_TIMING_PINS_FRAMING
      P1OUT &= ~BIT4;
      #endif
      setState(S_ROOT_IDLE);
      dataFrameSent = TRUE;
    #ifdef DEBUG_CX_FLOOD_P_TIMERS
    printf("psa.f from %u -> alarm %u actual %u claimed %u len %lu\n\r", psaBase, 
      call PrepareSendAlarm.getAlarm(), 
      psa_f,
      claimedFrame, 
      frameLen);
    printf("ms from %lu -> actual %lu \n\r", startTime, 
      psa_fms);
    printf("xt2 from %u -> alarm %u actual %u target %u\n\r", frameStart, 
      call SendAlarm.getAlarm(), saf, targetXT2);
    #endif

      sendDoneError = error;
    } else if (checkState(S_ROOT_FORWARDING)){
      setState(S_ROOT_IDLE);
    }else if (checkState(S_NR_DATA_SENDING)){
      #ifdef CX_FLOOD_TIMING_PINS_FRAMING
      P1OUT &= ~BIT4;
      #endif
      dataFrameSent = TRUE;
      setState(S_NR_IDLE);
      sendDoneError = error;
    } else if (checkState(S_NR_FORWARDING)){
      //TODO: occasionaly this is not hit prior to offtimer firing,
      //  which would i guess indicate that we're not seeing the
      //  sendDone from forwarding in some cases. 
      setState(S_NR_IDLE);
    } else {
      setState(S_ERROR_6);
    }
  }
 

  /**
   *  ROOT_RECEIVING: check for duplicate. 
   *    + duplicate: return msg
   *      -> ROOT_IDLE
   *    + new: swap from pool, load for tx. Store info in queue for
   *      reporting at end of period.
   *      -> ROOT_FORWARD_PREPARE
   *
   *  NR_RECEIVING: same, plus check type. 
   *    + announcement: update schedule vars, set inSynch, update
   *      ontimer/offtimer based on schedule info, reset
   *      failsafeCounter to 0.
   *      -> NR_FORWARD_PREPARE
   *    + non-announcement: 
   *      -> NR_FORWARD_PREPARE
   */
  event message_t* SubReceive.receive(message_t* msg, void* payload,
      uint8_t len){
    //duplicate packet: go back to previous idle state. If we were
    //  expecting this to be an announcement, kill the
    //  prepareSendAlarm. stop the retx.
    uint16_t thisSrc = call CXPacket.source(msg);
    uint8_t thisSn = call CXPacket.sn(msg);
    bool isDuplicate = (thisSrc == lastSrc) &&
      (thisSn == lastSn);
//    printf("%s: \n\r", __FUNCTION__);
    if (isDuplicate){
      message_t* ret;
      #ifdef DEBUG_CX_FLOOD_P_PACKET
      printf("RD{%u(%u) %u(%u) %x %x}\n\r", 
        call CXPacket.source(msg), lastSrc,
        call CXPacket.sn(msg), lastSn, call CXPacket.type(msg),
        call Rf1aPacket.crcPassed(msg));
      #endif
      call SendAlarm.stop();
      #ifdef DEBUG_CX_P
      printf("Duplicate\n\r");
      #endif 
      if (checkState(S_ROOT_RECEIVING)){
        setState(S_ROOT_IDLE);

      } else if (checkState(S_NR_RECEIVING)){
        if (!synchedThisRound){
          call PrepareSendAlarm.stop();   
          #ifdef CX_FLOOD_TIMING_PINS_FRAMING
          P1OUT &= ~BIT4;
          #endif
        }
        setState(S_NR_IDLE);

      } else {
        //root appears to *not* see own framestart?
        setState(S_ERROR_7);
      }
      //for reporting self-prr
      atomic{
        ret = call MessagePool.get();
        call MessageQueue.enqueue(msg);
        call LenQueue.enqueue(len);
      }
      return ret;
    } else{
      #ifdef DEBUG_CX_FLOOD_P_PACKET
      printf("RN{%u(%u) %u(%u) %x %x}\n\r", 
        call CXPacket.source(msg), lastSrc,
        call CXPacket.sn(msg), lastSn, call CXPacket.type(msg),
        call Rf1aPacket.crcPassed(msg));
      #endif
    }
    //TODO: testing: enforce topology here (source and count). Treat
    //      like duplicate if no match.

    //if we're waiting for it and this is an announcement, update our
    //onTimer/offTimer accordingly. Update synch state variables.
    if (checkState(S_NR_RECEIVING) && ! synchedThisRound){
      if (CX_TYPE_FLOOD_ANNOUNCEMENT == call CXPacket.type(msg)){
        cx_flood_announcement_t* pl = (cx_flood_announcement_t*) 
          (call LayerPacket.getPayload(msg, 
          sizeof(cx_flood_announcement_t)));
        period = pl->period;

        if (frameLen != pl->frameLen){
          //this alarm was set with stale information, so just kill it
          //  and pick it up next period.
          call PrepareSendAlarm.stop();
          #ifdef CX_FLOOD_TIMING_PINS_FRAMING
          P1OUT &= ~BIT4;
          #endif
        }
        frameLen = pl->frameLen;
        numFrames = pl->numFrames;
        synchedThisRound = TRUE;
        hasSynched = TRUE;
        failsafeCounter = 0;
        #ifdef DEBUG_CX_FLOOD_P
        printf("<p %lu fl %lu nf %u>\n\r", period, frameLen, numFrames);
        #endif
        #ifdef DEBUG_CX_FLOOD_P_TIMERS
        printf("Now: %lu OnTimer: %lu %lu offTimer: %lu %lu\n\r",
          call OnTimer.getNow(), startTime-CX_FLOOD_RADIO_START_SLACK, period, startTime,
          (frameLen >>5)*numFrames);
        #endif
        call OnTimer.startPeriodicAt(startTime - CX_FLOOD_RADIO_START_SLACK, period);
        call OffTimer.startOneShotAt(startTime, (frameLen >> 5 )* numFrames);
      } else {
        //not duplicate, but not a synch point either, so kill the
        //  prepareSendAlarm.
        call PrepareSendAlarm.stop();
        #ifdef CX_FLOOD_TIMING_PINS_FRAMING
        P1OUT &= ~BIT4;
        #endif
      }
    }

    if (checkState(S_ROOT_RECEIVING) ||
        checkState(S_NR_RECEIVING)){
      message_t* ret;
      //if pool is empty, refill from queue
      atomic {
        if (call MessagePool.empty()){
          ret = call MessageQueue.dequeue();
          printf("!dequeue %p\n\r", ret);
          //TODO: report queue drops!
          printf("!enpool %p\n\r", ret);
          call MessagePool.put(ret);
          call LenQueue.dequeue();
        }
        ret = call MessagePool.get();
      }

      call CXPacket.setCount(msg, call CXPacket.count(msg)+1);
      if (checkState(S_ROOT_RECEIVING)){
        setState(S_ROOT_FORWARD_PREPARE);
      } else {
        setState(S_NR_FORWARD_PREPARE);
      }
      #ifdef DEBUG_CX_FLOOD_P_PACKET
      printf("F{%u %u %x}\n\r", call CXPacket.source(msg), 
        call CXPacket.sn(msg), call CXPacket.type(msg)); 
      #endif
      if (SUCCESS != call SubSend.send(msg, len)){
        setState(S_ERROR_8);
      } else {
        #ifdef DEBUG_CX_FLOOD_P_BUFFERS
        printf("depool (ret) %p\n\r", ret);
        #endif
        lastSrc = call CXPacket.source(msg);
        lastSn = call CXPacket.sn(msg);
        //record packet/len for later reporting.
        atomic {
          call LenQueue.enqueue(len);
          call MessageQueue.enqueue(msg);
        }
        #ifdef DEBUG_CX_FLOOD_P_BUFFERS
        printf("enqueue (rx) %p\n\r", msg);
        #endif
      }
      return ret;

    } else {
      setState(S_ERROR_9);
      return msg;
    }
  }
  
  /**
   *  ROOT_IDLE: shut off lower layer 
   *    -> ROOT_STOPPING
   *
   *  NR_IDLE: shut off lower layer. 
   *    -> NR_STOPPING
   *
   */
  event void OffTimer.fired(){
    #ifdef DEBUG_CX_FLOOD_P
    printf("%s: %lu\n\r", __FUNCTION__, call OffTimer.getNow());
    #endif
    if (checkState(S_ROOT_IDLE) || checkState(S_NR_IDLE)){
      if (SUCCESS != call SubSplitControl.stop()){
        setState(S_ERROR_f);
      } else {
        if (checkState(S_ROOT_IDLE)){
          setState(S_ROOT_STOPPING);
        } else {
          setState(S_NR_STOPPING);
        }
      }
    } else {
      //TODO: observed at frame 2 owner during forwarding
      //  for frame 3, and during own-data sending
      //during forwarding for frame 3: this is the last frame, so
      //maybe the tolerance is just too tight?
      setState(S_ERROR_e);
    }
  }


  /**
   *  All: update radioOn. If dataFrame not null, signal sendDone with
   *       it and set to null.
   * 
   *  ROOT_STOPPING: post task to report receptions.
   *    + OnTimer is running: 
   *      -> ROOT_INACTIVE
   *    + OnTimer is not running: signal stopDone
   *      -> ROOT_OFF
   *
   *  NR_STOPPING: post task to report receptions. if we didn't synch
   *      this round, increment failsafe counter.
   *    + failsafeCounter exceeds limit: signal CXFloodControl
   *        interface that no synch was obtained.
   *      -> NR_OFF
   *    + OnTimer is running:
   *      -> NR_INACTIVE
   *    + OnTimer is not running:
   *      -> NR_OFF
   */
  event void SubSplitControl.stopDone(error_t error){
    #ifdef DEBUG_CX_FLOOD_P
    printf("%s: \n\r", __FUNCTION__);
    #endif
    if (error == SUCCESS){
      #ifdef DEBUG_CX_FLOOD_2
      P1OUT &= ~BIT1;
      #endif
      radioOn = FALSE;
    }
    if (checkState(S_ROOT_STOPPING)){
      if (call OnTimer.isRunning()){
        setState(S_ROOT_INACTIVE);
      } else {
        setState(S_ROOT_OFF);
        signal SplitControl.stopDone(SUCCESS);
      }
      if (dataFrame != NULL && dataFrameSent){
        signal Send.sendDone(dataFrame, sendDoneError);
        dataFrame = NULL;
      }
      post reportReceivesTask();

    } else if (checkState(S_NR_STOPPING)){
      if (failsafeCounter > CX_FLOOD_FAILSAFE_LIMIT){
        setState(S_NR_OFF);
        signal CXFloodControl.noSynch();
        //if this holds, we couldn't send it.
        sendDoneError = FAIL;
      } else {
        if (call OnTimer.isRunning()){
          setState(S_NR_INACTIVE);
          if (synchedThisRound){
            signal CXFloodControl.synchInfo(period, frameLen, numFrames);
          }
        } else {
          setState(S_NR_OFF);
          signal SplitControl.stopDone(SUCCESS);
        }
      }
      if (dataFrame != NULL){
        signal Send.sendDone(dataFrame, sendDoneError);
        dataFrame = NULL;
      }
      post reportReceivesTask();

    } else {
      setState(S_ERROR);
    }
  }


  /**
   *  ROOT_INACTIVE, NR_INACTIVE: call SubSplitControl.start
   *    -> no change
   * 
   *  NR_IDLE: if we get this, it means that we never left NR_IDLE
   *           from last round (i.e. we never set an off timer,
   *           because we never got the schedule announcement).
   *           Increment failsafe counter and stop the radio/timer if
   *           we exceed the failsafe count.
   *    -> NR_IDLE
   *
   */
  event void OnTimer.fired(){
    #ifdef DEBUG_CX_FLOOD_P
    printf("%s: %lu\n\r", __FUNCTION__, call OnTimer.getNow());
    #endif
    if (checkState(S_ROOT_INACTIVE) || checkState(S_NR_INACTIVE)){
      if (SUCCESS != call SubSplitControl.start()){
        setState(S_ERROR);
      }

    } else if(checkState(S_NR_IDLE)){
      #ifdef DEBUG_CX_FLOOD_P
      printf("no synch last round\n\r");
      #endif
      //This happens if we failed to get the synch.
      failsafeCounter++;
      if (failsafeCounter > CX_FLOOD_FAILSAFE_LIMIT){
        hasSynched = FALSE;
        call OnTimer.stop();
        setState(S_NR_STOPPING);
        if (SUCCESS != call SubSplitControl.stop()){
          setState(S_ERROR);
        }
      }

    } else {
      setState(S_ERROR);
    }
  }

  /**
   *  All: if no dataFrame pending, store the parameters. Set up CX
   *    header
   *
   */
  command error_t Send.send(message_t* msg, uint8_t len){
    #ifdef DEBUG_CX_FLOOD_P
    printf("%s: \n\r", __FUNCTION__);
    #endif
    if (checkState(S_NR_OFF) || checkState(S_ROOT_OFF)){
      return EOFF;
    }
    if (NULL == dataFrame){
      call CXPacket.setDestination(msg, call AMPacket.destination(msg));
      call AMPacket.setDestination(msg, AM_BROADCAST_ADDR);
      call CXPacket.setCount(msg, 0);
      call CXPacket.setType(msg, CX_TYPE_DATA);
      atomic {
        dataFrame = msg;
        dataFrameLen = len + sizeof(cx_header_t);
      }
      return SUCCESS;
    } else {
      return EBUSY;
    }
  }

  task void reportReceivesTask(){
    bool needReport = FALSE;
    void* pl;
    message_t* msg;
    uint8_t len;
    atomic {
      if (! call MessageQueue.empty()){
        needReport = TRUE;
        msg = call MessageQueue.dequeue();
        len = call LenQueue.dequeue();
      }
    }
    if (needReport){
      #ifdef DEBUG_CX_FLOOD_P_BUFFERS
      printf("RR\n\r");
      printf("dequeue %p\n\r", msg);
      #endif
      pl = call LayerPacket.getPayload(msg, len);
      //Only signal up data, keep CX internal stuff at this layer.
      if (call CXPacket.type(msg) == CX_TYPE_DATA){
        //unstash destination field
        call AMPacket.setDestination(msg, call
          CXPacket.destination(msg));
        msg = signal Receive.receive(msg, pl, len -
          sizeof(cx_header_t));
      } else {
        #ifdef DEBUG_CX_FLOOD_P_BUFFERS
        printf("in-layer\n\r");
        #endif
      }
      atomic {
        call MessagePool.put(msg);
      }
      #ifdef DEBUG_CX_FLOOD_P_BUFFERS
      printf("enpool %p\n\r", msg);
      printf("-----\n\r");
      #endif
      post reportReceivesTask();
    }
  }

  command error_t Send.cancel(message_t* msg){
    #ifdef DEBUG_CX_FLOOD_P
    printf("%s: \n\r", __FUNCTION__);
    #endif
    //TODO as long as we are not in one of the DATA_PREPARE or DATA_SENDING states, we can
    //  just set dataFrame to NULL and be done with it.
    return FAIL;
  }


  //TODO: for all of these, we want to make these changes at the
  //appropriate times. 
  //  For now, can only set root and period while in the off state. 
  //  The rest can be set during an inactive or off state.
  /**
   *  OFF:
   *    + isRoot = true
   *      -> ROOT_OFF
   *    + isRoot = false
   *      -> NR_OFF
   *
   */
  command error_t CXFloodControl.setRoot(bool isRoot){
    #ifdef DEBUG_CX_FLOOD_P
    printf("%s: \n\r", __FUNCTION__);
    #endif
    if (checkState(S_OFF) || checkState(S_ROOT_OFF) 
        || checkState(S_NR_OFF)){
      if (isRoot){
        setState(S_ROOT_OFF);
      } else {
        setState(S_NR_OFF);
      }
      return SUCCESS;
    } else {
      setState(S_ERROR);
      return FAIL;
    }
  }
  command error_t CXFloodControl.setPeriod(uint32_t period_){
    if (checkState(S_ROOT_OFF) || checkState(S_NR_OFF)){
      period = period_;
      return SUCCESS;
    } else {
      return EBUSY;
    }
  }
  command error_t CXFloodControl.setFrameLen(uint32_t frameLen_){
    if (checkState(S_ROOT_OFF) || checkState(S_ROOT_INACTIVE) ||
        checkState(S_NR_OFF) || checkState(S_NR_INACTIVE)){
      frameLen = frameLen_;
      return SUCCESS;
    } else {
      return EBUSY;
    }
  }
  command error_t CXFloodControl.setNumFrames(uint16_t numFrames_){
    if (checkState(S_ROOT_OFF) || checkState(S_ROOT_INACTIVE) ||
        checkState(S_NR_OFF) || checkState(S_NR_INACTIVE)){
      numFrames = numFrames_;
      return SUCCESS;
    } else {
      return EBUSY;
    }
  }
  command error_t CXFloodControl.claimFrame(uint16_t index){
    #ifdef DEBUG_CX_FLOOD_P
    printf("%s: \n\r", __FUNCTION__);
    #endif
    if (checkState(S_ROOT_OFF) || checkState(S_ROOT_INACTIVE) ||
        checkState(S_NR_OFF) || checkState(S_NR_INACTIVE)){
      claimedFrame = index;
      return SUCCESS;
    } else {
      return EBUSY;
    }
  }

  
  //TODO: implement these. Should go into frame announcement, i guess.
  command error_t CXFloodControl.assignFrame(uint16_t index, am_addr_t nodeId){ return FAIL; }
  command error_t CXFloodControl.freeFrame(uint16_t index){ return FAIL; }

  //always try to do rapid forwarding, no cca
  async command bool GetCCACheck.getNow(){ return FALSE;}
  async command bool GetFastReTX.getNow(){ return TRUE;}

  //unimplemented
  async command error_t PacketAcknowledgements.requestAck( message_t* msg ){ return FAIL; }
  async command error_t PacketAcknowledgements.noAck( message_t* msg ){return SUCCESS;}
  async command bool PacketAcknowledgements.wasAcked(message_t* msg){return FALSE;}

  //uninteresting stuff
  command void* Send.getPayload(message_t* msg, uint8_t len){ return call LayerPacket.getPayload(msg, len); }
  command uint8_t Send.maxPayloadLength(){ return call LayerPacket.maxPayloadLength(); }
  task void signalStopDoneTask(){ signal SplitControl.stopDone(SUCCESS); }
  task void signalStartDoneTask(){ signal SplitControl.startDone(SUCCESS); }

  //unused events
  async event void Rf1aPhysical.receiveDone (uint8_t* buffer,
      unsigned int count, int result) { }
  async event void Rf1aPhysical.receiveStarted (unsigned int length) { }
  async event void Rf1aPhysical.clearChannel () { } 
  async event void Rf1aPhysical.carrierSense () { } 
  async event void Rf1aPhysical.sendDone (int result) { }
  async event void Rf1aPhysical.receiveBufferFilled (uint8_t* buffer,
    unsigned int count) { }
  async event void Rf1aPhysical.released () { }


}
