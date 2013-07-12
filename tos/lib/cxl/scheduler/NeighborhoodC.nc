configuration NeighborhoodC {
  uses interface LppProbeSniffer;
  uses interface CXLinkPacket;
  uses interface Packet;
  provides interface Neighborhood;
  provides interface Init;
} implementation {
  components BasicNeighborhoodP as NeighborhoodP;

  LppProbeSniffer = NeighborhoodP;
  CXLinkPacket = NeighborhoodP;
  Packet = NeighborhoodP;
  Neighborhood = NeighborhoodP;
  Init = NeighborhoodP;
}
