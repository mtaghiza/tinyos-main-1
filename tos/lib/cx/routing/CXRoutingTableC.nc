configuration CXRoutingTableC {
  provides interface RoutingTable;
} implementation {
  //TODO: use CFLAGS to pick which RT mechanism to use
  components CXRoutingTableLastP as RoutingTableP;
  
  RoutingTable = RoutingTableP;
}
