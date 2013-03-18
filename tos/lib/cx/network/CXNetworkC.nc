
 #include "CXNetwork.h"
configuration CXNetworkC {
  provides interface SplitControl;
  provides interface CXRequestQueue;
  provides interface Packet;
  provides interface CXNetworkPacket;

} implementation {
  components CXNetworkP;

  components CXLinkC;
  
  SplitControl = CXLinkC;
  CXRequestQueue = CXNetworkP;
  Packet = CXNetworkP;
  CXNetworkPacket = CXNetworkP;

  CXNetworkP.SubCXRequestQueue -> CXLinkC;
  CXNetworkP.SubPacket -> CXLinkC;

  components new PoolC(cx_network_metadata_t);

}
