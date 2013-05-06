#include "GlobalID.h"

module CXAMInitP {
  uses interface GlobalID;
  provides interface Init;
  uses interface ActiveMessageAddress;
} implementation {

  command error_t Init.init(){
    uint8_t idb[GLOBAL_ID_LEN];
    if (SUCCESS == call GlobalID.getID(idb, GLOBAL_ID_LEN)){
      am_addr_t amAddr = idb[GLOBAL_ID_LEN -2];
      amAddr <<= 8;
      amAddr |= (idb[GLOBAL_ID_LEN-1]);
      //just use the 2 LSB as the address.
      call ActiveMessageAddress.setAddress(
        call ActiveMessageAddress.amGroup(),
        amAddr);
    }
    return SUCCESS;
  }

  async event void ActiveMessageAddress.changed(){}
}
