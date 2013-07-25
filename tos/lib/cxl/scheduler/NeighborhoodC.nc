configuration NeighborhoodC {
  uses interface LppProbeSniffer;
  uses interface CXLinkPacket;
  uses interface Packet;
  provides interface Neighborhood;
} implementation {
  components MainC;
  components BasicNeighborhoodP as NeighborhoodP;
  components RandomC;
  NeighborhoodP.Random -> RandomC;
  #if PHOENIX_LOGGING == 1
  components PhoenixNeighborhoodP;
  components new TimerMilliC();
  components SettingsStorageC;
  components RebootCounterC;

  PhoenixNeighborhoodP.Timer -> TimerMilliC;
  PhoenixNeighborhoodP.SettingsStorage -> SettingsStorageC;
  PhoenixNeighborhoodP.CXLinkPacket = CXLinkPacket;
  PhoenixNeighborhoodP.Packet = Packet;
  PhoenixNeighborhoodP.RebootCounter -> RebootCounterC;
  PhoenixNeighborhoodP.Boot -> MainC;
  PhoenixNeighborhoodP.Random -> RandomC;
  
  LppProbeSniffer = PhoenixNeighborhoodP.SubLppProbeSniffer;
  NeighborhoodP.LppProbeSniffer -> PhoenixNeighborhoodP.LppProbeSniffer;
  #else
  LppProbeSniffer = NeighborhoodP;
  #endif

  CXLinkPacket = NeighborhoodP;
  Packet = NeighborhoodP;
  Neighborhood = NeighborhoodP;
  MainC.SoftwareInit -> NeighborhoodP.Init;
}
