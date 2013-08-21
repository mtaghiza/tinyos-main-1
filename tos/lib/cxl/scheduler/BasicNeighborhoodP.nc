module BasicNeighborhoodP {
  uses interface LppProbeSniffer;
  uses interface CXLinkPacket;
  uses interface Packet;
  uses interface Random;
  provides interface Neighborhood;
  provides interface Init;
} implementation {
  nx_am_addr_t neighbors[CX_NEIGHBORHOOD_SIZE];
  uint8_t neighborIndex = 0;
  uint8_t numNeighbors;
  bool frozen;

  command error_t Init.init(){
    call Neighborhood.clear();
    return SUCCESS;
  }

  event message_t* LppProbeSniffer.sniffProbe(message_t* msg){
    uint8_t i = 0;
    am_addr_t src;
    if (! frozen){
      src = call CXLinkPacket.source(msg);
  
      for (i = 0; i < neighborIndex; i++){
        if (neighbors[i] == src){
          return msg;
        }
      }
      //add them to the neighborhood if we are still filling it OR with
      //50% chance of evicting a previous resident
      if (numNeighbors < CX_NEIGHBORHOOD_SIZE 
          || (call Random.rand32() & BIT1)){
        neighbors[neighborIndex] = src;
        neighborIndex = (neighborIndex + 1) % CX_NEIGHBORHOOD_SIZE;
      }
  //    printf("n %u\r\n", src);
      if (numNeighbors < CX_NEIGHBORHOOD_SIZE){
        numNeighbors ++;
      }
    }
    return msg;
  }

  event void LppProbeSniffer.sniffDone(error_t error){
  }

  command void Neighborhood.freeze(){
    frozen = TRUE;
  }

  command void Neighborhood.clear(){
    uint8_t i;
    numNeighbors = 0;
    neighborIndex = 0;
    frozen = FALSE;
    for (i = 0; i < CX_NEIGHBORHOOD_SIZE; i++){
      neighbors[i] = AM_BROADCAST_ADDR;
    }
  }

  command void Neighborhood.copyNeighborhood(nx_am_addr_t* dest){
    uint8_t i;
    for (i = 0; i < CX_NEIGHBORHOOD_SIZE; i++){
      dest[i] = neighbors[i];
    }
  }

  command nx_am_addr_t* Neighborhood.getNeighborhood(){
    return neighbors;
  }

  command uint8_t Neighborhood.numNeighbors(){
    return numNeighbors;
  }

}
