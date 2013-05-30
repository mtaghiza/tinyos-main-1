module DummyRadioStateLogC{
  provides interface RadioStateLog;
} implementation {
  command error_t RadioStateLog.dump(){
    return SUCCESS;
  }
}
