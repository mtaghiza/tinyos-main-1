#include "CXLink.h"
interface CXLinkPacket {
  command void setLen(message_t* msg, uint8_t len);
  command uint8_t len(message_t* msg);
  command cx_link_header_t* getLinkHeader(message_t* msg);
  command cx_link_metadata_t* getLinkMetadata(message_t* msg);

  command void setAllowRetx(message_t* msg, bool allow);
  command void setTSLoc(message_t* msg, nx_uint32_t* tsLoc);
}
