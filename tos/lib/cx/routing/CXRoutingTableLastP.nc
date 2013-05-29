#include "CXRoutingDebug.h"
module CXRoutingTableLastP {
  provides interface RoutingTable;
} implementation {
  uint8_t defaultDistance;
  uint8_t evictionIndex = 0;

  typedef struct rt_entry {
    am_addr_t src;
    am_addr_t dest;
    uint8_t distance;
  } rt_entry_t;
  
  //3 entries is minimum: end-to-end plus segment lengths
  #define RT_LEN 3
  rt_entry_t rt[RT_LEN];
  
  command uint8_t RoutingTable.getDistance(am_addr_t from, 
      am_addr_t to){
    if (to == AM_BROADCAST_ADDR){
      return defaultDistance;
    } else {
      uint8_t i;
      for (i = 0; i < RT_LEN; i++){
        if ((from == rt[i].src && to == rt[i].dest) 
            || (from == rt[i].dest && to == rt[i].src)){
          return rt[i].distance;
        }
      }
      cdbg(ROUTING, "DD %u %u\r\n", from, to);
      return defaultDistance;
    }
  }

  command error_t RoutingTable.addMeasurement(am_addr_t from, 
      am_addr_t to, uint8_t distance){
    uint8_t i;
    cdbg(ROUTING, "DAM %u %u %u:",
      from, to, distance);
    for(i=0; i < RT_LEN; i++){
      cdbg(ROUTING, " (%u %u)", rt[i].src, rt[i].dest);
      if ((from == rt[i].src && to == rt[i].dest) 
          || (from == rt[i].dest && to == rt[i].src)){
        cdbg(ROUTING, "*\r\n");
        rt[i].src = from;
        rt[i].dest = to;
        rt[i].distance = distance;
        return SUCCESS;
      }
    }
    cdbg(ROUTING, "\r\n");
    cdbg(ROUTING, "DE %u (%u %u)\r\n",
      evictionIndex,
      rt[evictionIndex].src,
      rt[evictionIndex].dest);

    rt[evictionIndex].src = from;
    rt[evictionIndex].dest = to;
    rt[evictionIndex].distance = distance;
    evictionIndex = (evictionIndex + 1 ) % RT_LEN;
    return SUCCESS;
  }

  command error_t RoutingTable.setDefault(uint8_t distance){
    defaultDistance = distance;
    return SUCCESS;
  }
  command uint8_t RoutingTable.getDefault(){
    return defaultDistance;
  }
}
