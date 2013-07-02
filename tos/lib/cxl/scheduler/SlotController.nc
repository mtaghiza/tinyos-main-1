
 #include "CXMac.h"
interface SlotController {
  command am_addr_t activeNode();
  command bool isMaster();
  command bool isActive();
  command uint8_t bw();
  command uint8_t maxDepth();
  command message_t* receiveEOS(message_t* msg, cx_eos_t* pl);
  command message_t* receiveStatus(message_t* msg, cx_status_t* pl);
  command void endSlot();
  command uint32_t wakeupLen();
}
