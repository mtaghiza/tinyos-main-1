interface SkewCorrection {
  command error_t addMeasurement(am_addr_t otherId, 
    uint32_t otherTS, uint32_t myTS, uint32_t originFrame);

  command int32_t getCorrection(am_addr_t otherId, 
    uint32_t framesElapsed);
}
