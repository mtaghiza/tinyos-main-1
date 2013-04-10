module FloodBurstP {
  provides interface Send;
  provides interface Receive;
  uses interface CXRequestQueue;
  uses interface CXTransportPacket;
} implementation {
  //send: if next tx frame is non-0, schedule TX and return result.
  //otherwise, return ERETRY

}
