configuration CXRoutingTableC{
  provides interface CXRoutingTable;
} implementation {
  components new CXRoutingTableP(CX_ROUTING_TABLE_ENTRIES);

  CXRoutingTable = CXRoutingTableP;
}
