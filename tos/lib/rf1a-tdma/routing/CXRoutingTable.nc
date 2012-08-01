interface CXRoutingTable{
  command error_t update(am_addr_t n0, am_addr_t n1, 
    uint8_t distance);
  command error_t isBetween(am_addr_t n0, am_addr_t n1, bool* result);
  command uint8_t distance(am_addr_t from, am_addr_t to);
  command uint8_t getBufferWidth();
}
