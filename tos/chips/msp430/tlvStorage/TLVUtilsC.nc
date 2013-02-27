 #include "TLVStorage.h"

generic configuration TLVUtilsC(uint8_t tlv_len){
  provides interface TLVUtils;
} implementation {
  enum {
    CLIENT_ID = unique(TLV_UTILS_CLIENT),
  };

  components TLVUtilsP;
  TLVUtils = TLVUtilsP.TLVUtils[CLIENT_ID];

  components new TLVLengthStoreC(tlv_len);
  TLVUtilsP.GetLength[CLIENT_ID] -> TLVLengthStoreC;
}
