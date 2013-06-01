module DummyRadioStateLogC{
  provides interface RadioStateLog;
} implementation {
  command uint32_t RadioStateLog.dump(){
    return 0;
  }
}
