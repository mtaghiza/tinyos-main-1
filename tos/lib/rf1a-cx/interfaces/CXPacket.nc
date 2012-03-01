//TODO: switch to cx_addr, cx_id 
interface CXPacket{
//  command am_addr_t address();
  command am_addr_t destination(message_t* amsg);
  command am_addr_t source(message_t* amsg);
  command void setDestination(message_t* amsg, am_addr_t addr);
  command void setSource(message_t* amsg, am_addr_t addr);
  command uint8_t sn(message_t* amsg);
  command void setSn(message_t* amsg, uint8_t cxsn);
  command uint8_t count(message_t* amsg);
  command void setCount(message_t* amsg, uint8_t cxcount);
  command bool isForMe(message_t* amsg);
  command am_id_t type(message_t* amsg);
  command void setType(message_t* amsg, am_id_t t);
}
