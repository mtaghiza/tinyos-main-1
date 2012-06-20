interface SlotStarted{
  event void slotStarted(uint16_t slotNum);
  command uint16_t currentSlot();
}
