interface RadioStateLog {
  //This will return a batch identifier, or "0" if no dump could be
  //started.
  //This can be used, for example, to assign meaningful labels to the
  //dumps.
  command uint32_t dump();
}
