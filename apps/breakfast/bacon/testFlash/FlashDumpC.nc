configuration FlashDumpC{
  provides interface FlashDump;
} implementation {
  components FlashDumpP;
  components Stm25pSpiC as SpiC;

  FlashDump = FlashDumpP;

  FlashDumpP.Resource -> SpiC.Resource;
  //hack: wire to same sector as LogStorageC
  //is this problematic? are we reading/writing to different volumes
  //somehow?
  FlashDumpP.Stm25pSpi -> SpiC;

}
