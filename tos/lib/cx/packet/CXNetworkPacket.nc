interface CXNetworkPacket {

  //reset hop count, set source address
  command error_t init(message_t* msg);

  command void setTTL(message_t* msg, uint8_t ttl); 
  command uint8_t getTTL(message_t* msg);

  command uint8_t getHops(message_t* msg);
  
  //if TTL positive, decrement TTL and increment hop count.
  //Return true if TTL is still positive after this step.
  command bool readyNextHop(message_t* msg);

}
