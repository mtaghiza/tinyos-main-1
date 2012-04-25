interface Sampler {
  command error_t startSampling(uint16_t sampleInterval);
  event bool burstDone(uint16_t numSamples);
}
