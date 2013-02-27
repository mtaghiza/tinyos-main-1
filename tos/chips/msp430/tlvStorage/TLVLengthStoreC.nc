generic module TLVLengthStoreC(uint8_t TLV_LEN){
  provides interface Get<uint8_t> as GetLength;
} implementation {
  command uint8_t GetLength.get(){ return TLV_LEN; }
}

