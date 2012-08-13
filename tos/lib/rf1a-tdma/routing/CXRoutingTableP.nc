 #include "CXRouting.h"
 #include "CXRoutingDebug.h"

generic module CXRoutingTableP(uint8_t numEntries){
  provides interface CXRoutingTable;
  provides interface Init;
} implementation {
  cx_route_entry_t rt[numEntries];
  uint8_t lastEvicted = numEntries-1;

  command error_t Init.init(){
    uint8_t i;
    for(i = 0; i < numEntries; i++){
      rt[i].used = FALSE;
      rt[i].pinned = FALSE;
    }
    return SUCCESS;
  }

  //TODO: bidirectionality?
  bool getEntry(cx_route_entry_t** re, am_addr_t n0, am_addr_t n1){
    uint8_t i = 0;
    for (i = 0; i < numEntries; i++){
      if ((rt[i].n0 == n0) && (rt[i].n1 == n1)){
        *re = &rt[i];
        return TRUE;
      }
    }
    return FALSE;
  }

  command uint8_t CXRoutingTable.distance(am_addr_t from, am_addr_t to){
    cx_route_entry_t* re;
    if (getEntry(&re, from, to)){
      return re->distance;
    }else{
      return 0xff;
    }
  }

  command error_t CXRoutingTable.update(am_addr_t n0, am_addr_t n1,
      uint8_t distance){
    uint8_t i;
    uint8_t checked = 0;
    cx_route_entry_t* re;
    //update and mark used-recently if it's already in the table.
    if (getEntry(&re, n0, n1)){
      #ifdef DEBUG_SF_TESTBED
      if (re->distance != distance){
        printf_ROUTING_TABLE("UR %u->%u %u \r\n", 
          n0,
          n1,
          distance);
      }
      #endif
      re->distance = distance;
      re->used = TRUE;
      return SUCCESS;
    }
    //start at lastEvicted+1
    i = (lastEvicted + 1)%numEntries;

    //look for one that hasn't been used recently, clearing LRU flag
    //as you go. Eventually we'll either find an unused slot or we'll
    //wrap around.
    while (rt[i].used && checked < CX_ROUTING_TABLE_ENTRIES + 1){
      if (!rt[i].pinned){
        rt[i].used = FALSE;
      }
      checked++;
      i = (i+1)%numEntries;
    }
    //Fail if there are no un-pinned entries.
    if (checked == CX_ROUTING_TABLE_ENTRIES + 1){
      return FAIL;
    }
    //save it
    printf_ROUTING_TABLE("NR %u->%u %u\r\n", n0, n1, distance);
    rt[i].n0 = n0;
    rt[i].n1 = n1;
    rt[i].distance = distance;
    rt[i].used = TRUE;
    //update for next time.
    lastEvicted = i;
    return SUCCESS;
  }

  command error_t CXRoutingTable.setPinned(am_addr_t n0, am_addr_t n1, bool pinned){
    cx_route_entry_t* re;
    if (getEntry(&re, n0, n1)){
      re->pinned = pinned;
      return SUCCESS;
    }
    return FAIL;
  }

  command uint8_t CXRoutingTable.getBufferWidth(){
    return CX_BUFFER_WIDTH;
  }

  command error_t CXRoutingTable.isBetween(am_addr_t n0, am_addr_t n1,
      bool* result){
    cx_route_entry_t* re; 
    if (n0 == AM_BROADCAST_ADDR || n1 == AM_BROADCAST_ADDR){
      *result = TRUE;
      return SUCCESS;
    }
    if (getEntry(&re, n0, TOS_NODE_ID)){
      uint8_t sm = re->distance;
      if (getEntry(&re, n1, TOS_NODE_ID)){
        uint8_t md = re->distance;
        if (getEntry(&re, n0, n1)){
          *result = sm + md <= (re->distance 
            + call CXRoutingTable.getBufferWidth());
          if (! *result){
            printf_ROUTING_TABLE("~");
          }
          printf_ROUTING_TABLE("IB %u->%u %u %u %u\r\n", 
            n0,
            n1,
            sm,
            md,
            re->distance);
          return SUCCESS;
        }else{
          printf_ROUTING_TABLE("~IB %u -> %u sd UNK\r\n", n0, n1);
        }
      }else{
        printf_ROUTING_TABLE("~IB %u -> %u dm UNK\r\n", n0, n1);
      }
    }else{
      printf_ROUTING_TABLE("~IB %u -> %u sm UNK\r\n", n0, n1);
    }
    return FAIL;
  }
}
