 #include "CXRouting.h"

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
    }
    return SUCCESS;
  }

  //TODO: bidirectionality?
  bool getEntry(cx_route_entry_t** re, am_addr_t n0, am_addr_t n1){
    uint8_t i = 0;
//    printf_BF("ge %p %x %x\r\n", re, n0, n1);
    for (i = 0; i < numEntries; i++){
//      printf_BF("%u (%p): %x %x\r\n", i, &rt[i], rt[i].n0, rt[i].n1);
      if ((rt[i].n0 == n0) && (rt[i].n1 == n1)){
//        printf_BF("match\r\n");
        *re = &rt[i];
        return TRUE;
      }
    }
//    printf_BF("no match\r\n");
    return FALSE;
  }

  command uint8_t CXRoutingTable.distance(am_addr_t from, am_addr_t to){
    cx_route_entry_t* re;
//    printf_BF("Distance\r\n");
    if (getEntry(&re, from, to)){
      return re->distance;
    }else{
      return 0xff;
    }
  }

  command error_t CXRoutingTable.update(am_addr_t n0, am_addr_t n1,
      uint8_t distance){
    uint8_t i;
    cx_route_entry_t* re;
//    printf_BF("Update\r\n");
    //update and mark used-recently if it's already in the table.
    if (getEntry(&re, n0, n1)){
      //TODO: debug only, remove
      if (re->distance != distance){
        printf_BF("w %p %x %x %u\r\n", re, n0, n1, distance);
      }
      re->distance = distance;
      re->used = TRUE;
      return SUCCESS;
    }
//    printf_BF("New\r\n");
    //start at lastEvicted+1
    i = (lastEvicted + 1)%numEntries;

    //look for one that hasn't been used recently, clearing LRU flag
    //as you go. Eventually we'll either find an unused slot or we'll
    //wrap around.
    while (rt[i].used){
      rt[i].used = FALSE;
      i = (i+1)%numEntries;
    }
    //save it
    printf_BF("wn %p %x %x %u\r\n", &rt[i], n0, n1, distance);
    rt[i].n0 = n0;
    rt[i].n1 = n1;
    rt[i].distance = distance;
    rt[i].used = TRUE;
    //update for next time.
    lastEvicted = i;
    return SUCCESS;
  }

  command error_t CXRoutingTable.isBetween(am_addr_t n0, am_addr_t n1,
      bool* result){
    cx_route_entry_t* re; 
    printf_BF("between\r\n");
    if (n0 == AM_BROADCAST_ADDR || n1 == AM_BROADCAST_ADDR){
      *result = TRUE;
      return SUCCESS;
    }
    if (getEntry(&re, n0, TOS_NODE_ID)){
      uint8_t sm = re->distance;
      if (getEntry(&re, n1, TOS_NODE_ID)){
        uint8_t md = re->distance;
        if (getEntry(&re, n0, n1)){
          *result = sm + md <= re->distance;
          return SUCCESS;
        }
      }
    }
    return FAIL;
  }
}
