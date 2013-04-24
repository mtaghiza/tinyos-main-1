interface SlotTiming {
  command uint32_t lastSlotStart();
  command uint32_t nextSlotStart(uint32_t fn);
  command uint32_t framesLeftInSlot(uint32_t fn);
}
