configuration FECRf1aFifoC{
  provides interface Rf1aFifo;
  uses interface HplMsp430Rf1aIf as Rf1aIf;
} implementation {
  components FECRf1aFifoP;
  FECRf1aFifoP.Rf1aIf = Rf1aIf;
  Rf1aFifo = FECRf1aFifoP;
}
