interface SkewCorrection {
  command error_t addMeasurement(am_addr_t otherId, 
    uint32_t otherTS, uint32_t originFrame, uint32_t myTS);

  command int32_t getCorrection(am_addr_t otherId, 
    uint32_t framesElapsed);

  command uint32_t referenceFrame(am_addr_t otherId);
  command uint32_t referenceTime(am_addr_t otherId);
}
