interface CXLinkPacket{
  command am_addr_t getSource(message_t* msg);
  command void setSource(message_t* msg);

  command am_addr_t addr();
}
