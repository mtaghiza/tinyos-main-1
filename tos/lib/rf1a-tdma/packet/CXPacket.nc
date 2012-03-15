#include "CX.h"
//TODO: switch to cx_addr, cx_id 
interface CXPacket{
//  command am_addr_t address();
  command void init(message_t* amsg);
  command am_addr_t destination(message_t* amsg);
  command am_addr_t source(message_t* amsg);
  command void setDestination(message_t* amsg, am_addr_t addr);
  command void setSource(message_t* amsg, am_addr_t addr);
  command uint8_t sn(message_t* amsg);
  async command void newSn(message_t* amsg);
  command uint8_t count(message_t* amsg);
  command void setCount(message_t* amsg, uint8_t cxcount);
  command bool isForMe(message_t* amsg);
  command am_id_t type(message_t* amsg);
  command void setType(message_t* amsg, am_id_t t);
  command void setRoutingMethod(message_t* amsg, uint8_t t);
  command uint8_t getRoutingMethod(message_t* amsg);
}
