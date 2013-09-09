configuration CXRoutingTableC {
  provides interface RoutingTable;
} implementation {
  components CXMinRoutingTableP as RoutingTableP;
  RoutingTable = RoutingTableP;
}

