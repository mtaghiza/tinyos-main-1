interface CXMacMaster{
  //Issue a CTS to some node in the network.
  command error_t cts(am_addr_t src);
  event void ctsDone(am_addr_t src, error_t error);
}
