interface Neighborhood{
  command void copyNeighborhood(nx_am_addr_t* dest);
  command nx_am_addr_t* getNeighborhood();
  command uint8_t numNeighbors();
  command void clear();
  command void freeze();
}
