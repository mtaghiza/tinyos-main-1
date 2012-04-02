interface StateTiming {
  async command void start(uint8_t state);
  async command uint32_t getTotal(uint8_t state);
  async command uint32_t getOverflows(uint8_t state);
}
