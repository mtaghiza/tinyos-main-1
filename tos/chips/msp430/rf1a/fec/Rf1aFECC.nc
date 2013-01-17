generic configuration Rf1aFECC () {
  provides interface Rf1aPhysical;
  provides interface Rf1aPhysicalMetadata;

  uses interface Rf1aPhysical as SubRf1aPhysical;
  uses interface Rf1aPhysicalMetadata as SubRf1aPhysicalMetadata;

  uses interface Rf1aTransmitFragment ;
  provides interface Rf1aTransmitFragment as SubRf1aTransmitFragment;
} implementation {
  components new Rf1aFECP();
  components CC430CRCC;

  //TODO: switch between encodings
  #if RF1A_FEC_ENABLED == 1
  components Hamming74FECC as FEC;
//  components DummyFECC as FEC;
  #else
  components DummyFECC as FEC;
  #endif

  Rf1aFECP.FEC -> FEC;
  
  //"normal" fragmentation
  components new DefaultRf1aTransmitFragmentC();
  Rf1aFECP.DefaultRf1aTransmitFragment -> DefaultRf1aTransmitFragmentC;
  Rf1aFECP.DefaultLength -> DefaultRf1aTransmitFragmentC;
  Rf1aFECP.DefaultBuffer -> DefaultRf1aTransmitFragmentC;

  Rf1aFECP.Crc -> CC430CRCC;

  Rf1aFECP.SubRf1aPhysical = SubRf1aPhysical;
  Rf1aPhysical = Rf1aFECP.Rf1aPhysical;

  Rf1aPhysicalMetadata = Rf1aFECP.Rf1aPhysicalMetadata;
  Rf1aFECP.SubRf1aPhysicalMetadata = SubRf1aPhysicalMetadata;

  Rf1aTransmitFragment = Rf1aFECP.Rf1aTransmitFragment;
  SubRf1aTransmitFragment = Rf1aFECP.SubRf1aTransmitFragment;

}
