interface Neighborhood{
  command void copyNeighborhood(void* dest);
  command nx_am_addr_t* getNeighborhood();
  command uint8_t numNeighbors();
}
