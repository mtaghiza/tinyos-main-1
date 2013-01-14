generic module DefaultRf1aTransmitFragmentC(){
  provides interface Rf1aTransmitFragment;
  provides interface SetNow<const uint8_t*> as SetBuffer;
  provides interface SetNow<uint8_t> as SetLength;
} implementation{
  const uint8_t* tx_pos = NULL;
  uint8_t bytesLeft = 0;
  
  async command unsigned int Rf1aTransmitFragment.transmitReadyCount(unsigned int count ){
    atomic {
      return (bytesLeft < count)? bytesLeft: count;
    }
  }

  async command const uint8_t* Rf1aTransmitFragment.transmitData(unsigned int count ){
    atomic{
      if (bytesLeft < count){
        return NULL;
      }else{
        const uint8_t* rv = tx_pos;
        tx_pos += count;
        bytesLeft -= count;
        return rv;
      }
    }
  }
   
  async command error_t SetBuffer.setNow(const uint8_t* buf){
    tx_pos = buf;
    return SUCCESS;
  }

  async command error_t SetLength.setNow(uint8_t len){
    bytesLeft = len;
    return SUCCESS;
  }

}
