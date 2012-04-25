interface Sampler {
  command error_t startSampling(uint16_t sampleInterval);
  event uint16_t* burstDone(uint16_t* buffer);
}
