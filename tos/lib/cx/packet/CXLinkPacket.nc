
 #include "AM.h"
interface CXLinkPacket{
  command am_addr_t getSource(message_t* msg);
  command void setSource(message_t* msg, am_addr_t addr);
  
  //set up 15.4 header as DATA packet, increment sequence
  //number, etc.
  command void init(message_t* msg);

  command am_addr_t addr();
}
