interface RoutingTable {
  command uint8_t getDistance(am_addr_t from, am_addr_t to);
  command error_t addMeasurement(am_addr_t from, am_addr_t to, 
    uint8_t distance);
  command error_t setDefault(uint8_t distance);
}
