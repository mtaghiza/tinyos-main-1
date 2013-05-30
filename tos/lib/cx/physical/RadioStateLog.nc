interface RadioStateLog {
  //logBatch is just some unique number used for labeling by an upper
  //layer. Output will be in the format 
  // "RS" logBatch state stateTotal 
  //for backwards compatibility with slot-specific duty cycle logging,
  //this should be combined with a
  // "LB" logBatch slotNumber
  // message from the upper layer.
  command error_t dump(uint32_t logBatch);
}
