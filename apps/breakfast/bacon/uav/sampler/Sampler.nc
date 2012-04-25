interface Sampler {
  command error_t startSampling(uint16_t sampleInterval, 
    bool startFromZero);
  command error_t stopSampling();
  event void burstDone(uint16_t numSamples);
  
  command error_t read(uint32_t addr, uint8_t* buf, uint16_t len);
  command uint32_t getEnd();
  event void readDone(uint32_t addr, uint8_t* buf, uint16_t len,
    error_t error);
}
