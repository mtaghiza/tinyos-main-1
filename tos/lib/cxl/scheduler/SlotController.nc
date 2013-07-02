interface SlotController {
  command am_addr_t activeNode();
  command bool isMaster();
  command bool isActive();
  command uint8_t bw();
  command uint8_t maxDepth();
  command message_t* receiveEOS(message_t* msg, void* pl);
  command message_t* receiveStatus(message_t* msg, void* pl);
  command void endSlot();
}
