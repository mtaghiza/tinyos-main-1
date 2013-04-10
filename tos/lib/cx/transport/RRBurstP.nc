module RRBurstP {
  provides interface Send;
  provides interface Receive;
  uses interface CXRequestQueue;
  uses interface CXTransportPacket;
  //for setup/ack packets
  uses interface Packet;
} implementation {
}
