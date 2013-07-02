module NeighborhoodC {
  uses interface LppProbeSniffer;
  provides interface Neighborhood;
  provides interface Init;
} implementation {
  nx_am_addr_t neighbors[CX_NEIGHBORHOOD_SIZE];
  uint8_t neighborIndex = 0;
  uint8_t numNeighbors;

  command error_t Init.init(){
    uint8_t i;
    for (i = 0; i < CX_NEIGHBORHOOD_SIZE; i++){
      neighbors[i] = AM_BROADCAST_ADDR;
    }
  }

  event void LppProbeSniffer.sniffProbe(am_addr_t src){
    neighbors[neighborIndex] = src;
    neighborIndex = (neighborIndex + 1) % CX_NEIGHBORHOOD_SIZE;
    if (numNeighbors < CX_NEIGHBORHOOD_SIZE){
      numNeighbors ++;
    }
  }

  command void Neighborhood.clear(){
    numNeighbors = 0;
    neighborIndex = 0;
  }

  command void Neighborhood.copyNeighborhood(void* dest){
    memcpy(dest, neighbors, sizeof(neighbors));
  }

  command nx_am_addr_t* Neighborhood.getNeighborhood(){
    return neighbors;
  }

  command uint8_t Neighborhood.numNeighbors(){
    return numNeighbors;
  }

}
