 #include "CXRouting.h"
configuration CXRoutingTableC{
  provides interface CXRoutingTable;
} implementation {
  #if CX_FORWARDER_SELECTION == 0
  components new CXRoutingTableP(CX_ROUTING_TABLE_ENTRIES);
  #elif CX_FORWARDER_SELECTION == 1
  components new CXAverageRoutingTableP(CX_ROUTING_TABLE_ENTRIES) 
    as CXRoutingTableP;
  #elif CX_FORWARDER_SELECTION == 2
  components new CXMaxRoutingTableP(CX_ROUTING_TABLE_ENTRIES) 
    as CXRoutingTableP;
  components LocalTimeMilliC;
  CXRoutingTableP.LocalTime -> LocalTimeMilliC;
  #else
  #error Unrecognized CX_FORWARDER_SELECTION option: 0=instant, 1=avg, 2=max
  #endif
//  components new SafeCXRoutingTableP(CX_ROUTING_TABLE_ENTRIES) as CXRoutingTableP;
  components MainC;
  CXRoutingTable = CXRoutingTableP;
  MainC.SoftwareInit -> CXRoutingTableP;
}
