module DummyCXLinkPacketC {
  provides interface CXLinkPacket;
} implementation {
  cx_link_header_t dummyHeader;
  cx_link_metadata_t dummyMetadata;

  command void CXLinkPacket.setLen(message_t* msg, uint8_t len){}
  command uint8_t CXLinkPacket.len(message_t* msg){return 0;}
  command cx_link_header_t* CXLinkPacket.getLinkHeader(message_t* msg){return &dummyHeader;}
  command cx_link_metadata_t* CXLinkPacket.getLinkMetadata(message_t* msg){return &dummyMetadata;}
  command rf1a_metadata_t* CXLinkPacket.getPhyMetadata(message_t* msg){return NULL;}

  command void CXLinkPacket.setAllowRetx(message_t* msg, bool allow){}
//  command void setTSLoc(message_t* msg, nx_uint32_t* tsLoc);

  command void CXLinkPacket.setTtl(message_t* msg, uint8_t ttl){}
  command am_addr_t CXLinkPacket.source(message_t* msg){return 0;}
  command void CXLinkPacket.setSource(message_t* msg, am_addr_t addr){}
  command am_addr_t CXLinkPacket.destination(message_t* msg){ return 0; }
  command void CXLinkPacket.setDestination(message_t* msg, am_addr_t addr){}
  command uint8_t CXLinkPacket.rxHopCount(message_t* msg){ return 0; }
  command uint16_t CXLinkPacket.getSn(message_t* msg){ return 0; }
  
}
