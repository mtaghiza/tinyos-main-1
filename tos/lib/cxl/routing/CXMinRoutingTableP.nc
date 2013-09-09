
 #include "CXRoutingDebug.h"

module CXMinRoutingTableP {
  provides interface RoutingTable;
} implementation {
  uint8_t defaultDistance = CX_MAX_DEPTH;
  uint8_t rti = 0;

  typedef struct rt_entry {
    am_addr_t n0;
    am_addr_t n1;
    uint8_t distance;
  } rt_entry_t;

  #define RT_LEN 3
  rt_entry_t rt[RT_LEN];

  command error_t RoutingTable.addMeasurement(am_addr_t from, 
      am_addr_t to, uint8_t distance){
    if (from == AM_BROADCAST_ADDR || to == AM_BROADCAST_ADDR){
      return EINVAL;
    }
    rt[rti].n0 = from < to? from : to;
    rt[rti].n1 = from < to? to : from;
    rt[rti].distance = distance;
    rti = (rti+1)%RT_LEN;
    return SUCCESS;
  }

  command uint8_t RoutingTable.getDistance(am_addr_t from, 
      am_addr_t to){
    am_addr_t n0 = from < to? from: to;
    am_addr_t n1 = to < from? to: from;
    uint8_t i;
    for (i =0; i< RT_LEN; i++){
      if (rt[i].n0 == n0 && rt[i].n1 == n1){
        return rt[i].distance;
      }
    }
    return call RoutingTable.getDefault();
  }

  command error_t RoutingTable.setDefault(uint8_t distance){
    defaultDistance = distance;
    return SUCCESS;
  }

  command uint8_t RoutingTable.getDefault(){
    return defaultDistance;
  }
}
