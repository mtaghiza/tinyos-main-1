configuration FECRf1aFifoC{
  provides interface Rf1aFifo;
  uses interface HplMsp430Rf1aIf as Rf1aIf;
} implementation {
  components CC430CRCC;

  #if FEC_HAMMING74 == 1
  components Hamming74Rf1aFifoP as FECRf1aFifoP;
  #else
  components DoubleRf1aFifoP as FECRf1aFifoP;
  #endif
  FECRf1aFifoP.Crc -> CC430CRCC;
  FECRf1aFifoP.Rf1aIf = Rf1aIf;
  Rf1aFifo = FECRf1aFifoP;
}
