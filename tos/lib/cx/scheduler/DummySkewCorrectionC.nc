module DummySkewCorrectionC {
  provides interface SkewCorrection;
} implementation {
  command error_t SkewCorrection.addMeasurement(am_addr_t otherId, 
      uint32_t otherTS, uint32_t myTS, 
      uint32_t originFrame){
    return SUCCESS;
  }

  command int32_t SkewCorrection.getCorrection(am_addr_t otherId, 
      uint32_t framesElapsed){
    return 0;
  }
}
