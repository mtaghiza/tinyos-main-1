interface FEC {
  /**
   *  Encode decodedLen bytes of data from decoded to encoded, return
   *  the length of the encoded buffer.
   */
  async command uint8_t encode(uint8_t* decoded, uint8_t* encoded,
      uint8_t decodedLen);
  
  /**
   *  Decode encodedLen bytes of data from encoded to decoded, return
   *  the length of the decoded buffer.
   */
  async command uint8_t decode(uint8_t* encoded, uint8_t* decoded, 
      uint8_t encodedLen);
}
