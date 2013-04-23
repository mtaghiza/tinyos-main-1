#include "message.h"
module CXPacketMetadataC {
  provides interface CXPacketMetadata;
} implementation {
  cx_metadata_t* getMd(message_t* msg){
    return &((message_metadata_t*)(msg->metadata))->cx;
  }

  command uint32_t CXPacketMetadata.getRequestedFrame(message_t* msg){
    return getMd(msg)->scheduledFrame;
  }

  command void CXPacketMetadata.setRequestedFrame(message_t* msg, uint32_t rf){
    cx_metadata_t* md = getMd(msg);
    md->scheduledFrame = rf;
  }

  command nx_uint32_t* CXPacketMetadata.getTSLoc(message_t* msg){
    return getMd(msg)->tsLoc;
  }

  command void CXPacketMetadata.setTSLoc(message_t* msg, 
      nx_uint32_t* tsLoc){
    cx_metadata_t* md = getMd(msg);
    md->tsLoc = tsLoc;
  }
}
