configuration FECRf1aFifoC{
  provides interface Rf1aFifo;
  uses interface HplMsp430Rf1aIf as Rf1aIf;
} implementation {
  #if FEC_HAMMING74 == 1
  components CC430CRCC;
  components Hamming74Rf1aFifoP as FECRf1aFifoP;
  FECRf1aFifoP.Crc -> CC430CRCC;
  #else
  components DoubleRf1aFifoP as FECRf1aFifoP;
  #endif
  FECRf1aFifoP.Rf1aIf = Rf1aIf;
  Rf1aFifo = FECRf1aFifoP;
}
