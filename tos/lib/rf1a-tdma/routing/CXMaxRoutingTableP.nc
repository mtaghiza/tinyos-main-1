 #include "CXRouting.h"
 #include "CXMaxRouting.h"
 #include "CXRoutingDebug.h"

generic module CXMaxRoutingTableP(uint8_t numEntries){
  provides interface CXRoutingTable;
  provides interface Init;
  uses interface Timer<TMilli>;
} implementation {
  cx_max_route_entry_t rt[numEntries];
  uint8_t lastEvicted = numEntries-1;

  uint8_t curDump;
  bool dumping = FALSE;
  
  uint32_t now(){
    return call Timer.getNow();
  }
  //just using the timer for getNow
  event void Timer.fired(){}

  task void nextDumpTask(){
    cx_max_route_entry_t* re;
    if (curDump == 0){
      printf("# RT Now: %lu\r\n", now());
    }
    printf("# MAX RT[%d] %d->%d = %d %lu (%d %d) ", 
      curDump, rt[curDump].n0, rt[curDump].n1, 
      rt[curDump].distance,
      rt[curDump].lastSeen,
      rt[curDump].used, 
      rt[curDump].pinned);
    printf(" lu: %d", 
      call CXRoutingTable.distance(rt[curDump].n0, rt[curDump].n1, FALSE));
    printf(" rev: %d \r\n", 
      call CXRoutingTable.distance(rt[curDump].n1, rt[curDump].n0, TRUE));
    curDump ++;
    if (curDump < numEntries){
      post nextDumpTask();
    }else{
      dumping = FALSE;
    }
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

  bool getEntry(cx_max_route_entry_t** re, am_addr_t n0, am_addr_t n1,
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

  command uint8_t CXRoutingTable.distance(am_addr_t from, am_addr_t to, 
      bool bdOK){
    cx_max_route_entry_t* re;
    if (from == TOS_NODE_ID && to == TOS_NODE_ID){
      return 0;
    }
    if (getEntry(&re, from, to, bdOK)){
      return re->distance;
    }else{
      return 0xff;
    }
  }

  command error_t CXRoutingTable.update(am_addr_t n0, am_addr_t n1,
      uint8_t distance){
    uint8_t i;
    uint8_t checked = 0;
    cx_max_route_entry_t* re;
    uint32_t ts = now();
    if (getEntry(&re, n0, n1, FALSE)){
      //record this if it meets/exceeds current max distance. Replace
      //current max distance if it's expired.
      printf_TMP("MAX UR %u -> %u (%u, %lu) => (%u, %lu) =>",
        n0, n1, 
        re->distance, re->lastSeen,
        distance, ts);
      if ( distance >= re->distance || 
        (ts - re->lastSeen > CX_ROUTING_TABLE_TIMEOUT) ){
        re->distance = distance;
        re->lastSeen = ts;
      } 
      printf_TMP("(%u, %lu)\r\n", re->distance, re->lastSeen);
      //mark used-recently if it's already in the table.
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
    rt[i].n0 = n0;
    rt[i].n1 = n1;
    rt[i].distance = distance;
    rt[i].lastSeen = now;
    rt[i].used = TRUE;
    printf_ROUTING_TABLE("MAX NR %u->%u (%u, %lu)\r\n", 
      n0, n1,
      rt[i].distance, rt[i].lastSeen);
    //update for next time.
    lastEvicted = i;
    return SUCCESS;
  }

  command error_t CXRoutingTable.setPinned(am_addr_t n0, am_addr_t n1,
      bool pinned, bool bdOK){
    cx_max_route_entry_t* re;
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
    cx_max_route_entry_t* re; 
    if (n0 == AM_BROADCAST_ADDR || n1 == AM_BROADCAST_ADDR 
        || n0 == TOS_NODE_ID || n1== TOS_NODE_ID){
      *result = TRUE;
      return SUCCESS;
    }
    if (getEntry(&re, n0, TOS_NODE_ID, bdOK)){
      uint8_t sm = re->distance;
      if (getEntry(&re, TOS_NODE_ID, n1, bdOK)){
        uint8_t md = re->distance;
        if (getEntry(&re, n0, n1, bdOK)){
          *result = sm + md <= (re->distance + call CXRoutingTable.getBufferWidth());
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

