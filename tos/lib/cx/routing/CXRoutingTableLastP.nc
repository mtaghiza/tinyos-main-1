module CXRoutingTableLastP {
  provides interface RoutingTable;
} implementation {
  uint8_t defaultDistance;

  command uint8_t RoutingTable.getDistance(am_addr_t from, 
      am_addr_t to){
    if (to == AM_BROADCAST_ADDR){
      return defaultDistance;
    } else {
      //TODO: look up
      return defaultDistance;
    }
  }

  command error_t RoutingTable.addMeasurement(am_addr_t from, 
      am_addr_t to, uint8_t distance){
    //TODO: find/set
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
