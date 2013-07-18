
 #include "CXRouter.h"
 #include "CXRouterDebug.h"
module CXMasterP {
  provides interface SlotController;
  provides interface CXDownload[uint8_t ns];

  uses interface LppControl;
  uses interface Neighborhood;
  uses interface ActiveMessageAddress;
  provides interface CTS[uint8_t ns];
  provides interface Receive;

  uses interface Get<probe_schedule_t*>;
} implementation {

  /**
   *  Download Flow:
   *  - call LppControl.wakeup / clear contact list
   *  - gather some sniffs/insert into contact list
   *  - designate first node sniffed as active
   *  - on receiving status, put any new nodes into contact list
   *  - on receiving EOS, mark node as finished or outstanding
   *  - update isActive accordingly
   **/

  contact_entry_t contactList[CX_MAX_SUBNETWORK_SIZE];
  uint8_t contactIndex;
  uint8_t toContact;
  uint8_t activeNS = NS_INVALID;

  command error_t CXDownload.startDownload[uint8_t ns](){
    if (ns != NS_ROUTER && ns != NS_SUBNETWORK && ns != NS_GLOBAL){
      return EINVAL;
    }
    if (activeNS != NS_INVALID){
      return EBUSY;
    }else if ((call Get.get())->invFrequency[ns] == 0){
      return EINVAL;
    } else {
      error_t error = call LppControl.wakeup(ns);
      if (error == SUCCESS){
        memset(contactList, sizeof(contactList), 0xFF);
        //put ourselves in as the first contact: each download will
        //start off with packets from us.
        contactList[0].nodeId = call ActiveMessageAddress.amAddress();
        contactIndex = 0;
        toContact = 1;
      }
      return error;
    }
  }

  task void downloadFinished(){
    cinfo(ROUTER, "Download finished\r\n");
    signal CXDownload.downloadFinished[activeNS]();
  }

  command void SlotController.endSlot(){
    if (toContact > 0){
      cinfo(ROUTER, "Done with %u: c %x p %x\r\n",
        contactList[contactIndex].nodeId,
        contactList[contactIndex].contacted,
        contactList[contactIndex].dataPending);
      contactIndex++;
      toContact --;
    }
    if (toContact == 0){
      post downloadFinished();
    }
  }

  command bool SlotController.isActive(){
    if (contactIndex == 0){
      uint8_t numNeighbors = call Neighborhood.numNeighbors();
      nx_am_addr_t* neighbors = call Neighborhood.getNeighborhood();
      uint8_t i;
      for (i = 0; i < numNeighbors; i++){
        contactList[i + 1].nodeId = neighbors[i];
        contactList[i + 1].contacted = FALSE;
      }
      toContact += numNeighbors;
    }
    return (toContact > 0);
  }

  command am_addr_t SlotController.activeNode(){
    contactList[contactIndex].attempted = TRUE;
    return contactList[contactIndex].nodeId;
  }

  command message_t* SlotController.receiveStatus(message_t* msg,
      cx_status_t* pl){
    uint8_t i;
    uint8_t k;
    contactList[contactIndex].contacted = TRUE;
    cdbg(ROUTER, "rs %u\r\n", contactList[contactIndex].nodeId);
    for (i = 0; i < CX_NEIGHBORHOOD_SIZE; i++){
      if (pl->neighbors[i] != AM_BROADCAST_ADDR){
        bool found = FALSE;
        for (k = 0; k < CX_MAX_SUBNETWORK_SIZE && !found; k++){
          if (contactList[k].nodeId == pl->neighbors[i]){
            found = TRUE;
          }
        }
        if (! found){
          if (toContact + contactIndex < CX_MAX_SUBNETWORK_SIZE){
            contactList[toContact + contactIndex].nodeId = pl->neighbors[i];
            contactList[toContact + contactIndex].contacted = FALSE;
            contactList[toContact + contactIndex].attempted = FALSE;
            cdbg(ROUTER, "Add %x at %u toContact %u\r\n",
              pl->neighbors[i], 
              toContact+contactIndex, 
              toContact+1);
            toContact ++;
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

  default event message_t* Receive.receive(message_t* msg, void* pl,
      uint8_t len){
    return msg;
  }

  command bool SlotController.isMaster(){
    return TRUE;
  }

  command uint8_t SlotController.bw(uint8_t ns){
    probe_schedule_t* sched = call Get.get();
    return sched->bw[ns];
  }

  command uint8_t SlotController.maxDepth(uint8_t ns){
    probe_schedule_t* sched = call Get.get();
    return sched->maxDepth[ns];
  }

  command uint32_t SlotController.wakeupLen(uint8_t ns){
    probe_schedule_t* sched = call Get.get();
    return ((sched->invFrequency[ns]*(sched->probeInterval)) << 5) * call SlotController.maxDepth(ns);
  }

  command message_t* SlotController.receiveEOS(message_t* msg,
      cx_eos_t* pl){
    contactList[contactIndex].dataPending = pl->dataPending;
    cdbg(ROUTER, "node %u pending %u\r\n",
      contactList[contactIndex].nodeId,
      contactList[contactIndex].dataPending);
    return msg;
  }

  command void SlotController.receiveCTS(uint8_t ns){
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


  
}
