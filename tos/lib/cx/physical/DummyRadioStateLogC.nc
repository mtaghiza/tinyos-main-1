module DummyRadioStateLogC{
  provides interface RadioStateLog;
} implementation {
  command error_t RadioStateLog.dump(uint32_t logBatch){
    return SUCCESS;
  }
}
