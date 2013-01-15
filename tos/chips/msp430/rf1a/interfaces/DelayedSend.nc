interface DelayedSend{
  event void sendReady();
  async command error_t startSend();
}
