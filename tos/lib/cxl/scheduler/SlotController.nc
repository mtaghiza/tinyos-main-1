
 #include "CXMac.h"
interface SlotController {
  command am_addr_t activeNode();
  command bool isMaster();
  command bool isActive();
  command uint8_t bw(uint8_t ns);
  command uint8_t maxDepth(uint8_t ns);
  command message_t* receiveEOS(message_t* msg, cx_eos_t* pl);
  command message_t* receiveStatus(message_t* msg, cx_status_t* pl);
  command void receiveCTS(am_addr_t master, uint8_t activeNS);
  command void endSlot();
}
