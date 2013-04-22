module CXPacketMetadataC {
  provides interface CXPacketMetadata;
} implementation {

  command uint32_t CXPacketMetadata.getRequestedFrame(message_t* msg){
    cx_metadata_t* md = (cx_metadata_t*)(msg->header);
    return md->scheduledFrame;
  }

  command void CXPacketMetadata.setRequestedFrame(message_t* msg, uint32_t rf){
    cx_metadata_t* md = (cx_metadata_t*)(msg->header);
    md->scheduledFrame = rf;
  }
}
