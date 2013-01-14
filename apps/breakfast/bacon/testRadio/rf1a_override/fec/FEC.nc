interface FEC {
  /**
   *  Encode decodedLen bytes of data from decoded to encoded, return
   *  the length of the encoded buffer.
   */
  async command uint8_t encode(const uint8_t* decoded, uint8_t* encoded,
      uint8_t decodedLen);
  
  /**
   *  Decode encodedLen bytes of data from encoded to decoded, return
   *  the length of the decoded buffer.
   */
  async command uint8_t decode(const uint8_t* encoded, uint8_t* decoded, 
      uint8_t encodedLen);

  /**
   *  Get the number of encoded bytes required to represent some
   *  number of raw bytes.
   */
  async command uint8_t encodedLen(uint8_t rawLen);
}
