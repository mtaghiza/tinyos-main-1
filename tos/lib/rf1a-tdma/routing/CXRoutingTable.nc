interface CXRoutingTable{
  command error_t update(am_addr_t n0, am_addr_t n1, 
    uint8_t distance, bool incremental);
  command error_t isBetween(am_addr_t n0, am_addr_t n1, 
    bool bdOK, bool* result);
  command uint8_t selectionDistance(am_addr_t from, am_addr_t to, bool bdOK);
  command uint8_t advertiseDistance(am_addr_t from, am_addr_t to, bool bdOK);
  command uint8_t getBufferWidth();
  command error_t setPinned(am_addr_t n0, am_addr_t n1, bool pinned,
    bool bdOK);
  command void dumpTable();

}
