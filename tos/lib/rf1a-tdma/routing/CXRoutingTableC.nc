 #include "CXRouting.h"
configuration CXRoutingTableC{
  provides interface CXRoutingTable;
} implementation {
  components new CXRoutingTableP(CX_ROUTING_TABLE_ENTRIES);
  components MainC;
  CXRoutingTable = CXRoutingTableP;
  MainC.SoftwareInit -> CXRoutingTableP;
}
