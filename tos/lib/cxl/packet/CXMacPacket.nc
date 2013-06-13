interface CXMacPacket {
  command uint8_t getMacType(message_t* msg);
  command void setMacType(message_t* msg, uint8_t macType);
}
