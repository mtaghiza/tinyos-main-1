 #include "CXRouting.h"

generic module SafeCXRoutingTableP(uint8_t numEntries){
  provides interface CXRoutingTable;
  provides interface Init;
} implementation {
  cx_route_entry_t rt[numEntries];
  uint8_t lastEvicted = 0;

  command error_t Init.init(){
    return SUCCESS;
  }

  command uint8_t CXRoutingTable.distance(am_addr_t from, am_addr_t to){
    return 2;
  }

  command error_t CXRoutingTable.update(am_addr_t n0, am_addr_t n1,
      uint8_t distance){
    return SUCCESS;
  }

  command error_t CXRoutingTable.isBetween(am_addr_t n0, am_addr_t n1,
      bool* result){
    *result = TRUE;
    return SUCCESS;
  }
}

