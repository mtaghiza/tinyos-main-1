interface SDLogger {
  command error_t writeRecords(uint16_t* buffer, uint8_t recordCount);
}
