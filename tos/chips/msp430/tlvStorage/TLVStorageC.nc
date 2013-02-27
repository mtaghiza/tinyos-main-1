#include "TLVStorage.h"
#include "InternalFlash.h"

configuration TLVStorageC{
  provides interface TLVStorage;
  provides interface TLVUtils;
} implementation {
  components new TLVStorageP((uint16_t)IFLASH_A_START, 
    (uint16_t)IFLASH_B_START, 
    IFLASH_SEGMENT_SIZE);
  components new TLVUtilsC(IFLASH_SEGMENT_SIZE);

  TLVStorageP.TLVUtils -> TLVUtilsC;

  TLVStorage = TLVStorageP;
  TLVUtils = TLVUtilsC;
}
