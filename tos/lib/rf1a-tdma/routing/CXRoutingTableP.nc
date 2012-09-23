 #include "CXRouting.h"
 #include "CXRoutingDebug.h"

generic module CXRoutingTableP(uint8_t numEntries){
  provides interface CXRoutingTable;
  provides interface Init;
} implementation {
  cx_route_entry_t rt[numEntries];
  uint8_t lastEvicted = numEntries-1;

  uint8_t curDump;
  bool dumping = FALSE;

  task void nextDumpTask(){
    cx_route_entry_t* re;
    printf_TMP("# INS RT[%d] %d->%d = %d (%d %d) ", 
      curDump, rt[curDump].n0, rt[curDump].n1, 
      rt[curDump].distance, rt[curDump].used, rt[curDump].pinned);
    printf_TMP(" lu: %d", 
      call CXRoutingTable.selectionDistance(rt[curDump].n0, rt[curDump].n1, FALSE));
    printf_TMP(" rev: %d \r\n", 
      call CXRoutingTable.selectionDistance(rt[curDump].n1, rt[curDump].n0, TRUE));
  }

  command void CXRoutingTable.dumpTable(){
    if (! dumping){
      curDump = 0;
      dumping = TRUE;
      post nextDumpTask();
    }
  }

  command error_t Init.init(){
    uint8_t i;
    for(i = 0; i < numEntries; i++){
      rt[i].used = FALSE;
      rt[i].pinned = FALSE;
    }
    return SUCCESS;
  }

  bool getEntry(cx_route_entry_t** re, am_addr_t n0, am_addr_t n1,
      bool bdOK){
    uint8_t i = 0;
    for (i = 0; i < numEntries; i++){
      if ((rt[i].n0 == n0) && (rt[i].n1 == n1)){
        *re = &rt[i];
        return TRUE;
      }
    }
    if (bdOK){
      for (i = 0; i < numEntries; i++){
        if ((rt[i].n0 == n1) && (rt[i].n1 == n0)){
          *re = &rt[i];
          return TRUE;
        }
      }
    }
    return FALSE;
  }

  command uint8_t CXRoutingTable.selectionDistance(am_addr_t from, am_addr_t to, 
      bool bdOK){
    cx_route_entry_t* re;
    if (from == TOS_NODE_ID && to == TOS_NODE_ID){
      return 0;
    }
    if (getEntry(&re, from, to, bdOK)){
      return re->distance;
    }else{
      return 0xff;
    }
  }
  command uint8_t CXRoutingTable.advertiseDistance(am_addr_t from, am_addr_t to, 
      bool bdOK){
    return call CXRoutingTable.selectionDistance(from, to, bdOK);
  }

  command error_t CXRoutingTable.update(am_addr_t n0, am_addr_t n1,
      uint8_t distance){
    uint8_t i;
    uint8_t checked = 0;
    cx_route_entry_t* re;
    //update and mark used-recently if it's already in the table.
    if (getEntry(&re, n0, n1, FALSE)){
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

    while (rt[i].used && checked < CX_ROUTING_TABLE_ENTRIES ){
      if (!rt[i].pinned){
        rt[i].used = FALSE;
      }else{
        checked++;
      }
      i = (i+1)%numEntries;
    }
    //Fail if there are no un-pinned entries
    if (rt[i].pinned){
      printf("~No unpinned RT entries!\r\n");
      call CXRoutingTable.dumpTable();
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

  command error_t CXRoutingTable.setPinned(am_addr_t n0, am_addr_t n1,
      bool pinned, bool bdOK){
    cx_route_entry_t* re;
    error_t err = FAIL;
    //make sure that we pin both directions...
//    printf_TMP("Pin %d -> %d: %d %d e=", n0, n1, pinned, bdOK);
    if (getEntry(&re, n0, n1, FALSE)){
      err = SUCCESS;
      re->pinned = pinned;
    }    
    if (bdOK){
      if (getEntry(&re, n1, n0, FALSE)){
        err = SUCCESS;
        re->pinned = pinned;
      }
    }
//    printf_TMP("%x\r\n", err);
//    call CXRoutingTable.dumpTable();

    return err;
  }

  command uint8_t CXRoutingTable.getBufferWidth(){
    return CX_BUFFER_WIDTH;
  }

  command error_t CXRoutingTable.isBetween(am_addr_t n0, am_addr_t n1,
      bool bdOK, bool* result){
    if (n0 == AM_BROADCAST_ADDR || n1 == AM_BROADCAST_ADDR 
        || n0 == TOS_NODE_ID || n1== TOS_NODE_ID){
      *result = TRUE;
      return SUCCESS;
    }
    {
      uint8_t sm = call CXRoutingTable.selectionDistance(n0, 
        TOS_NODE_ID, bdOK);
      if (sm < 0xff){
        uint8_t md = call CXRoutingTable.selectionDistance(TOS_NODE_ID,
          n1, bdOK);
        if (md < 0xff){
          uint8_t sd = call CXRoutingTable.advertiseDistance(n0, n1,
            bdOK);
          if (sd < 0xff){
            *result = sm + md <= sd + call CXRoutingTable.getBufferWidth();
            if (! *result){
              printf_ROUTING_TABLE("~");
            }
            printf_ROUTING_TABLE("IB %u->%u %u %u %u\r\n", 
              n0,
              n1,
              sm,
              md,
              sd);
            return SUCCESS;
          }else{
            printf_ROUTING_TABLE("~IB %u -> %u sd UNK\r\n", n0, n1);
          }
        }else{
          printf_ROUTING_TABLE("~IB %u -> %u md UNK\r\n", n0, n1);
        }
      }else{
        printf_ROUTING_TABLE("~IB %u -> %u sm UNK\r\n", n0, n1);
      }
      return FAIL;
    }
  }

}
