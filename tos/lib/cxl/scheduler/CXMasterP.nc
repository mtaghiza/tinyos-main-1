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


 #include "CXRouter.h"
 #include "CXRouterDebug.h"
 #include "networkMembership.h"
module CXMasterP {
  provides interface SlotController;
  provides interface CXDownload[uint8_t ns];

  uses interface LppControl;
  uses interface Neighborhood;
  uses interface ActiveMessageAddress;
  provides interface CTS[uint8_t ns];
  provides interface Receive;

  uses interface Get<probe_schedule_t*> as GetProbeSchedule;
  provides interface Get<am_addr_t> as GetRoot[uint8_t ns];

  uses interface SettingsStorage;

  uses interface CXLinkPacket;

  uses interface LogWrite;

  uses interface Leds;
} implementation {

  contact_entry_t contactList[CX_MAX_SUBNETWORK_SIZE];
  uint8_t contactIndex;
  uint16_t numRounds;
  uint8_t totalNodes;
  uint8_t activeNS = NS_INVALID;
  nx_uint16_t maxRounds; 
  //= DEFAULT_MAX_DOWNLOAD_ROUNDS;
  uint8_t maxAttempts = DEFAULT_MAX_ATTEMPTS;

  am_addr_t masters[NUM_SEGMENTS] = {AM_BROADCAST_ADDR, 
                                     AM_BROADCAST_ADDR, 
                                     AM_BROADCAST_ADDR};
  
  network_membership_t membership;

  #ifdef SLOT_LIMIT
  int16_t slotsLeft;
  #endif

  command am_addr_t GetRoot.get[uint8_t ns](){
    return masters[ns];
  }

  command error_t CXDownload.startDownload[uint8_t ns](){
    if (ns != NS_ROUTER && ns != NS_SUBNETWORK && ns != NS_GLOBAL){
      return EINVAL;
    }
    if (activeNS == ns){
      return EBUSY;
    }else if(activeNS != NS_INVALID){
      return ERETRY;
    } else if ((call GetProbeSchedule.get())->maxDepth[ns] == 0){
      return FAIL;
    } else {
      error_t error = call LppControl.wakeup(ns);
      if (error == SUCCESS){
        maxRounds = DEFAULT_MAX_DOWNLOAD_ROUNDS;
        #ifdef SLOT_LIMIT
        slotsLeft = SLOT_LIMIT;
        #endif
        call SettingsStorage.get(SS_KEY_MAX_DOWNLOAD_ROUNDS,
          &maxRounds, sizeof(maxRounds));
        //Initialization
        // - Put self in contact list, set totalNodes to 1 (just self)
        // - set self DP to true
        // - point to start of list
        // - clear num rounds counter
        // - initialize the membership report struct
        memset(contactList, 0xFF, sizeof(contactList));
        contactList[0].nodeId = call ActiveMessageAddress.amAddress();
        contactList[0].dataPending = TRUE;
        contactList[0].failedAttempts = 0;
        contactIndex = 0;
        totalNodes = 1;
        numRounds = 0;
  
        memset(&membership.members, 0xFF, sizeof(membership.members));
        memset(&membership.distances, 0xFF, sizeof(membership.distances));
        membership.masterId = call ActiveMessageAddress.amAddress();
        membership.recordType = RECORD_TYPE_NETWORK_MEMBERSHIP;
        membership.networkSegment = ns;
        membership.channel = (call GetProbeSchedule.get())->channel[ns];
        membership.members[0] = call ActiveMessageAddress.amAddress();
//        //RC, TS will be set via receiveStatus
      }
      return error;
    }
  }

  task void logMembership(){
    call LogWrite.append(&membership, sizeof(membership));
  }

  event void LogWrite.appendDone(void* buf, storage_len_t len, bool recordsLost, error_t error){}
  event void LogWrite.eraseDone(error_t error){}
  event void LogWrite.syncDone(error_t error){}

  task void downloadFinished(){
    cinfo(ROUTER, "Download finished\r\n");
    signal CXDownload.downloadFinished[activeNS]();
  }
  
  void finish(){
    post logMembership();
    post downloadFinished();
  }

  command bool SlotController.isActive(){
    #ifdef SLOT_LIMIT
    if (slotsLeft){
      slotsLeft --;
    }else{
      printf("SLE\r\n");
      finish();
      return FALSE;
    }
    #endif
    if (numRounds >= maxRounds){
      printf("IA0\r\n");
      finish();
      return FALSE;
    }
    
    signal CXDownload.nextAssignment[activeNS](
      contactList[contactIndex].nodeId,
      contactList[contactIndex].dataPending,
      contactList[contactIndex].failedAttempts);
//    printf("ia %u %u/%u -> ", numRounds, contactIndex, totalNodes);
    //Loop through contact list (wrapping contactIndex at totalNodes) until you either:
    // - hit a node with pending data
    // - complete the maxRounds-th loop of the entire list
    while (numRounds < maxRounds 
        && (!contactList[contactIndex].dataPending 
          || (contactList[contactIndex].failedAttempts >= maxAttempts))){
      contactIndex++;
      if (contactIndex >= totalNodes){
        contactIndex = contactIndex % totalNodes;
        numRounds++;
      }
      signal CXDownload.nextAssignment[activeNS](
        contactList[contactIndex].nodeId,
        contactList[contactIndex].dataPending,
        contactList[contactIndex].failedAttempts);
    }
//    printf("%u %u\r\n", numRounds, contactIndex);
    //If the above loop did not put you over the maxRounds limit, then
    // we're pointing at a node with pending data. go go go
    if (numRounds < maxRounds){
      //don't worry, we'll decrement this if we get a status back
      contactList[contactIndex].failedAttempts ++;
      contactList[contactIndex].contactFlag = FALSE;
      if (contactList[contactIndex].failedAttempts >= maxAttempts){
        cdbg(ROUTER, "me %u %u\r\n", contactList[contactIndex].nodeId, contactList[contactIndex].failedAttempts);
      }
      return TRUE;
    }else {
      printf("MRE %u >= %u\r\n", numRounds, maxRounds);
      //If we did exceed the limit, then we're done, and contactIndex
      //  is pointing at a node with pending data.
      finish();
      return FALSE;
    }
  }
  
  //Since the above isActive loop leaves us pointing at a node with
  //  pending data, just return the node at contactIndex.
  command am_addr_t SlotController.activeNode(){
//    printf("an %x\r\n", contactList[contactIndex].nodeId);
    return contactList[contactIndex].nodeId;
  }
  
  //If we get a status message from the active node (potentially
  //  ourself):
  // - Update dataPending for this node
  // - add any newly-discovered neighbors to the list and increment
  //   totalNodes to reflect them.
  command message_t* SlotController.receiveStatus(message_t* msg,
      cx_status_t* pl){
    //Can this be moved into a task? might be kind of slow.
    uint8_t i;
    uint8_t k;
    contactList[contactIndex].dataPending = pl->dataPending;
    contactList[contactIndex].contactFlag = TRUE;
    contactList[contactIndex].failedAttempts = 0;
//    printf("pl %p\r\n", pl->neighbors);
//    cdbg(ROUTER, "rs %u %u\r\n", 
//      contactList[contactIndex].nodeId,
//      contactList[contactIndex].dataPending);
    
    //if we've got this node recorded in network membership, fill in
    //its distance.
    for (k = 0; k < totalNodes && k < MAX_NETWORK_MEMBERS; k++){
      if (membership.members[k] == call CXLinkPacket.source(msg)){
        membership.distances[k] = pl->distance;
        if (membership.members[k] == 
            call ActiveMessageAddress.amAddress()){
          membership.rc = pl->wakeupRC;
          membership.ts = pl->wakeupTS;
        }
        break;
      }
    }
    for (i = 0; i < CX_NEIGHBORHOOD_SIZE; i++){
//      printf("? %p %x\r\n", &(pl->neighbors[i]), pl->neighbors[i]);
      if (pl->neighbors[i] != AM_BROADCAST_ADDR){
        bool found = FALSE;
        for (k = 0; k < totalNodes; k++){
          if (contactList[k].nodeId == pl->neighbors[i]){
            found = TRUE;
            break;
          }
        }
        if (! found){
          if (totalNodes < CX_MAX_SUBNETWORK_SIZE){
            contactList[totalNodes].nodeId = pl->neighbors[i];
            contactList[totalNodes].dataPending = TRUE;
            contactList[totalNodes].failedAttempts = 0;
//            printf( "A %x %u->%u\r\n",
//              pl->neighbors[i], 
//              i,
//              totalNodes);
            //add to network membership. Distance defaults to 0xFF
            if (totalNodes < MAX_NETWORK_MEMBERS){
              membership.members[totalNodes] = pl->neighbors[i];
            }
            totalNodes ++;

          }else {
            cwarn(ROUTER, 
              "No space to add %x to contact list\r\n",
              pl->neighbors[i]);
          }
        }
      }
    }

    return signal Receive.receive(msg, pl, sizeof(cx_status_t));
  }
  
  //If we get an EOS message from the active node (potentially
  //  ourself):
  // - update dataPending for the node.
  command message_t* SlotController.receiveEOS(message_t* msg,
      cx_eos_t* pl){
    contactList[contactIndex].dataPending = pl->dataPending;
    cdbg(ROUTER, "EDP %u %u\r\n",
      contactList[contactIndex].nodeId,
      contactList[contactIndex].dataPending);
    return msg;
  }

  am_addr_t eosAddr;
  eos_status_t eosStatus;

  task void signalEOS(){
    signal CXDownload.eos[activeNS](eosAddr, eosStatus);
  }
  
  //At the end of a slot, increment contactIndex, wrap if needed.
  command void SlotController.endSlot(){
    eosAddr = contactList[contactIndex].nodeId;
    eosStatus = contactList[contactIndex].contactFlag
        ? (contactList[contactIndex].dataPending? ES_DATA: ES_NO_DATA)
        : ES_NO_CONTACT;
    post signalEOS();

//    printf("es %u/%u ->", contactIndex, totalNodes);
    contactIndex++;
    if (contactIndex >= totalNodes){
      contactIndex = contactIndex % totalNodes;
      numRounds++;
    }
//    printf("%u\r\n", contactIndex);
  }


  command error_t CXDownload.markPending[uint8_t ns](am_addr_t addr){
    uint8_t i;
    for (i=0; i < totalNodes; i++){
      if (contactList[i].nodeId == addr){
        contactList[i].dataPending = TRUE;
        contactList[i].failedAttempts = 0;
        return SUCCESS;
      }
    }
    return FAIL;
  }

  default event message_t* Receive.receive(message_t* msg, void* pl,
      uint8_t len){
    return msg;
  }

  command bool SlotController.isMaster(){
    return TRUE;
  }

  command uint8_t SlotController.bw(uint8_t ns){
    probe_schedule_t* sched = call GetProbeSchedule.get();
    return sched->bw[ns];
  }

  command uint8_t SlotController.maxDepth(uint8_t ns){
    probe_schedule_t* sched = call GetProbeSchedule.get();
    return sched->maxDepth[ns];
  }


  command void SlotController.receiveCTS(am_addr_t master, uint8_t ns){
    masters[ns] = master;
    signal CTS.ctsReceived[ns]();
  }

  async event void ActiveMessageAddress.changed(){}
  
  event void LppControl.fellAsleep(){
    activeNS = NS_INVALID;
  }

  event void LppControl.wokenUp(uint8_t ns){
    activeNS = ns;
  }

  default event void CTS.ctsReceived[uint8_t ns](){}
  default event void CXDownload.downloadFinished[uint8_t ns](){}
  default event void CXDownload.nextAssignment[uint8_t ns](am_addr_t owner, bool dataPending, uint8_t failedAttempts){}
  default event void CXDownload.eos[uint8_t ns](am_addr_t owner, eos_status_t status){}

  default command error_t LogWrite.append(void* buf, storage_len_t len){ return FAIL;}
  default command storage_cookie_t LogWrite.currentOffset(){ return 0; }
  default command error_t LogWrite.erase(){return FAIL;}
  default command error_t LogWrite.sync(){return FAIL;}
  
}
