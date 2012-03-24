 #include "CXRouting.h"
configuration CXRoutingTableC{
  provides interface CXRoutingTable;
} implementation {
  components new CXRoutingTableP(CX_ROUTING_TABLE_ENTRIES);
//  components new SafeCXRoutingTableP(CX_ROUTING_TABLE_ENTRIES) as CXRoutingTableP;
  components MainC;
  CXRoutingTable = CXRoutingTableP;
  MainC.SoftwareInit -> CXRoutingTableP;
}
