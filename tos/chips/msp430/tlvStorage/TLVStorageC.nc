#include "TLVStorage.h"
#include "InternalFlash.h"

configuration TLVStorageC{
  provides interface TLVStorage;
  provides interface TLVUtils;
} implementation {
  components TLVStorageP;
  components new TLVUtilsC(IFLASH_SEGMENT_SIZE);

  TLVStorageP.TLVUtils -> TLVUtilsC;

  TLVStorage = TLVStorageP;
  //TODO: wire init
  TLVUtils = TLVUtilsC;
}
