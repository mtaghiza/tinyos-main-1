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

 #include "schedule.h"
 #include "NSFUnreliableBurst.h"
 #include "NSFUnreliableBurstDebug.h"
 #include "CX.h"
module UnreliableBurstSchedulerP{
  provides interface CXTransportSchedule;
  uses interface TDMARoutingSchedule;
  uses interface SlotStarted;

  provides interface Send;
  provides interface Receive;

  uses interface Send as FloodSend;
  uses interface Receive as FloodReceive;

  uses interface Send as ScopedFloodSend;
  uses interface Receive as ScopedFloodReceive;

  uses interface AMPacket;
  uses interface Packet as AMPacketBody;
  uses interface Packet as CXPacketBody;
  uses interface CXPacket;
  uses interface CXPacketMetadata;
  uses interface CXRoutingTable;
  uses interface Rf1aPacket;
} implementation {
  enum {
    M_ERROR = 0x10,
    S_ERROR_0 = 0x10,
    S_ERROR_1 = 0x11,
    S_ERROR_2 = 0x12,
    S_ERROR_3 = 0x13,
    S_ERROR_4 = 0x14,
    S_ERROR_5 = 0x15,
    S_ERROR_6 = 0x16,
    S_ERROR_7 = 0x17,

    S_IDLE = 0x00,
    S_SETUP_SENDING = 0x01,
    S_READY = 0x02,
    S_SENDING = 0x03
  };

  uint8_t state = S_IDLE;
  am_addr_t lastDest = AM_BROADCAST_ADDR;
  uint16_t curSlot = INVALID_SLOT;

  message_t setup_msg_internal;
  message_t* setup_msg = &setup_msg_internal;
  message_t* pendingMsg;
  uint8_t pendingLen;
  
  void newSlot(uint16_t slotNum);

  command error_t Send.send(message_t* msg, uint8_t len){
    //ugh. this is to handle the case where AMSend.send is called from
    //some other component's SlotStarted event BEFORE our
    //SlotStarted event has fired and set up for the new slot.
    am_addr_t addr = call CXPacket.destination(msg);
//    printf_TMP("am\r\n");
    if (state & M_ERROR){
      return FAIL;
    }
    newSlot(call SlotStarted.currentSlot());
    //unicast only
    if (addr == AM_BROADCAST_ADDR){
      return EINVAL;
    } else {
      error_t error;
      call CXPacketMetadata.setRequiresClear(msg, TRUE);
      call CXPacket.setTransportType(msg, CX_TYPE_DATA);

      //Idle or ready (but for a different destination):
      //  We need to set up a new route
      if (state == S_IDLE || (state == S_READY && addr != lastDest)){
        nsf_setup_t* pl = (nsf_setup_t*) (call CXPacketBody.getPayload(setup_msg, sizeof(nsf_setup_t)));
        pl -> src = call CXPacket.destination(msg);
        pl -> dest = TOS_NODE_ID;
        pl -> distance = call CXRoutingTable.advertiseDistance(pl->src,
          pl->dest, FALSE);
        call CXPacket.setNetworkProtocol(setup_msg, CX_NP_NONE);
        call CXPacket.setTransportType(setup_msg, CX_TYPE_SETUP);
        call CXPacket.setDestination(setup_msg, addr);
        call AMPacket.setDestination(setup_msg, AM_BROADCAST_ADDR);
        call CXPacketBody.setPayloadLength(setup_msg,
          sizeof(nsf_setup_t));
        call CXPacketMetadata.setRequiresClear(setup_msg, TRUE);
        error = call FloodSend.send(setup_msg, sizeof(nsf_setup_t));
//        printf_TMP("SU msg: %p PL: %p src: %d dest: %d dist: %d\r\n",
//          setup_msg, pl, 
//          pl->src, pl->dest, pl->distance);
        if (error == SUCCESS){
          pendingMsg = msg;
          pendingLen = len;
          state = S_SETUP_SENDING;
          lastDest = addr;
        }
      //sending along an established set of paths
      } else if (state == S_READY && addr == lastDest){
        call CXPacket.setNetworkProtocol(msg, CX_NP_PREROUTED);
        pendingMsg = msg;
        error = call FloodSend.send(msg, len);
        if (error == SUCCESS){
          state = S_SENDING;
        }
      }else{
        printf("!UB.S: sending\r\n");
        error = EBUSY;
      }

      //SUCCESS: OK, we're going to send it. 
      //RETRY: not enough time in this slot
      if (error != SUCCESS && error != ERETRY){
        state = S_ERROR_0;
        printf("!UB.S: Error: %s\r\n", decodeError(error));
      }
//      printf_TMP("UB.S: %s\r\n", decodeError(error));
      return error;
    }
  }
  
  event void ScopedFloodSend.sendDone(message_t* msg, error_t error){
    printf("!UB.SFS.sd: should not be signalled.\r\n");
    state = S_ERROR_1;
  }

  task void sendPendingTask(){
    if (state == S_READY && pendingMsg != NULL){
      error_t err;
      call CXPacket.setNetworkProtocol(pendingMsg, CX_NP_PREROUTED);
      err = call FloodSend.send(pendingMsg, pendingLen);
      if (err == SUCCESS){
        state = S_SENDING;
      }else{ 
        //RETRY is handled by AM queuing layer.
        if (err != ERETRY){
          state = S_ERROR_2;
        }
        signal Send.sendDone(pendingMsg, err);
      }
    }
  }

  event void FloodSend.sendDone(message_t* msg, error_t error){
//    printf_TMP("fs.sd\r\n");
    if (error != SUCCESS){
      printf("!UB.FS.sd: %s\r\n", decodeError(error));
      state = S_ERROR_3;
      return;
    }
    
    //setup sent: go to ready and try to send pending data.
    if (state == S_SETUP_SENDING && 
        call CXPacket.getTransportType(msg) == CX_TYPE_SETUP){
      state = S_READY;
      printf_UB("UBS s: %d d: %d sn: %d\r\n",
        call CXPacket.source(msg),
        call CXPacket.destination(msg),
        call CXPacket.sn(msg));
      printf_APP("TX s: %u d: %u sn: %u ofn: %u np: %u pr: %u tp: %u am: %u e: %u\r\n",
        TOS_NODE_ID,
        call CXPacket.destination(msg),
        call CXPacket.sn(msg),
        call CXPacket.getOriginalFrameNum(msg),
        (call CXPacket.getNetworkProtocol(msg)) & ~CX_NP_PREROUTED,
        ((call CXPacket.getNetworkProtocol(msg)) & CX_NP_PREROUTED)?1:0,
        call CXPacket.getTransportProtocol(msg),
        call AMPacket.type(msg),
        error);
      post sendPendingTask();

    //data sent: go to ready and signal up
    } else if (state == S_SENDING && 
        call CXPacket.getTransportType(msg) == CX_TYPE_DATA){
      state = S_READY;
      pendingMsg = NULL;
      signal Send.sendDone(msg, error);
    
    //something else: error.
    } else{
      printf("!UB.FS.sd: in %x\r\n", state);
      state = S_ERROR_4;
      return;
    }
  }

  void printRX(message_t* msg){
    printf_APP("RX s: %u d: %u sn: %u o: %u c: %u r: %d l: %u\r\n", 
      call CXPacket.source(msg),
      call CXPacket.destination(msg),
      call CXPacket.sn(msg),
      call CXPacket.getOriginalFrameNum(msg),
      call CXPacketMetadata.getReceivedCount(msg),
      call Rf1aPacket.rssi(msg),
      call Rf1aPacket.lqi(msg)
      );
  }

  event message_t* FloodReceive.receive(message_t* msg, void* payload,
      uint8_t len){
    if (call CXPacket.getTransportType(msg) == CX_TYPE_DATA){
      return signal Receive.receive(msg, payload, len);
    }else if (call CXPacket.getTransportType(msg) == CX_TYPE_SETUP){
      nsf_setup_t* pl = (nsf_setup_t*)payload;
      bool isBetween;
      am_addr_t src = call CXPacket.source(msg);
      am_addr_t dest = call CXPacket.destination(msg);
      uint8_t sm;
      uint8_t md;
      uint8_t sd;
      uint8_t bw = call CXRoutingTable.getBufferWidth();
//      printf_TMP("SU msg: %p PL: %p src: %d dest: %d dist: %d\r\n",
//        msg, pl, 
//        pl->src, pl->dest, pl->distance);
      call CXRoutingTable.update(pl->src, pl->dest, pl->distance, FALSE);
      sm = call CXRoutingTable.selectionDistance(src, TOS_NODE_ID, TRUE);
      md = call CXRoutingTable.selectionDistance(TOS_NODE_ID, dest, TRUE);
      sd = call CXRoutingTable.advertiseDistance(src, dest, TRUE);
      if ( SUCCESS != 
          call CXRoutingTable.isBetween(src, dest, TRUE, &isBetween)){
        isBetween = FALSE;
      }

      printRX(msg);
      //diagnostic info: did we receive / are we on circuit?
      printf_UB("UBF s: %d d: %d sn: %d sm: %d md: %d sd: %d bw: %d f: %d\r\n", 
        src, 
        dest, 
        call CXPacket.sn(msg), 
        sm,
        md,
        sd,
        bw,
        isBetween);
      if (call TDMARoutingSchedule.isSynched() 
          && (sm == 0xff || sd == 0xff || md == 0xff)){
        call CXRoutingTable.dumpTable();
      }
      //shut 'er down
      if (! isBetween){
        call TDMARoutingSchedule.inactiveSlot();
      }
      return msg;
    }else{
      state = S_ERROR_5;
      return msg;
    }
  }

  event message_t* ScopedFloodReceive.receive(message_t* msg, void* payload, uint8_t len){
    state = S_ERROR_6;
    return msg;
  }

  command bool CXTransportSchedule.isOrigin(uint16_t frameNum){
    if (call TDMARoutingSchedule.isSynched() &&
        call TDMARoutingSchedule.ownsFrame(frameNum)){
      return TRUE;
    }else{
      return FALSE;
    }
  }

  void newSlot(uint16_t slotNum){
    if (slotNum != curSlot){
      lastDest = AM_BROADCAST_ADDR;
      curSlot = slotNum;
//      printf_TMP("%u\r\n", curSlot);
      //in some cases, we can end up getting the slotStarted event
      //before seeing the sendDone event (even though the last
      //transmission did not violate a slot boundary)
      //e.g. at frame 98 we supply a packet. it gets sent in frame 99.
      //when frame 100 starts (new slot), the flood layer posts a task
      //to signal sendDone, but directly signals the slotStarted event.
      if (state == S_READY){
        state = S_IDLE;
      }else if (state != S_IDLE){
        if (state != S_ERROR_7){
          printf("!NSF.UB.SS.SS in %x\r\n", state);
        }
        state = S_ERROR_7;
      }
    }else{
//      printf_TMP("\r\n");
    }
  }

  event void SlotStarted.slotStarted(uint16_t slotNum){
//    printf_TMP("ss");
    newSlot(slotNum);
  }

  command error_t Send.cancel(message_t* msg){
    return FAIL;
  }

  command uint8_t Send.maxPayloadLength(){
    //TODO: shouldn't this be CXPacketBody?
    return call AMPacketBody.maxPayloadLength();
  }

  command void* Send.getPayload(message_t* msg, 
      uint8_t len){
    return call AMPacketBody.getPayload(msg, len);
  }


} 
