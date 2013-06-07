interface CXLink {
  command error_t sleep();

  command error_t rx(uint32_t timeout);
  event void rxDone();

  command error_t rxTone(uint32_t timeout);
  event void toneReceived(bool received);

  command error_t txTone(uint8_t depth);
  event void toneSent();
}
