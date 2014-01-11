/*
 * Copyright (c) 2014 Johns Hopkins University.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
*/

 #include "CXRouting.h"
 #include "CXMaxRouting.h"
 #include "CXRoutingDebug.h"

generic module CXMaxRoutingTableP(uint8_t numEntries){
  provides interface CXRoutingTable;
  provides interface Init;
  uses interface LocalTime<TMilli>;
} implementation {
  cx_max_route_entry_t rt[numEntries];
  uint8_t lastEvicted = numEntries-1;

  uint8_t curDump;
  bool dumping = FALSE;
  
  uint32_t now(){
    return call LocalTime.get();
  }

  task void nextDumpTask(){
    cx_max_route_entry_t* re;
    if (curDump == 0){
      printf("# RT Now: %lu\r\n", now());
    }
    printf("# MAX RT[%d] %d->%d = M (%d, %lu) m (%d, %lu) (%d %d) ", 
      curDump, rt[curDump].n0, rt[curDump].n1, 
      rt[curDump].maxDistance,
      rt[curDump].lastMax,
      rt[curDump].minDistance,
      rt[curDump].lastMin,
      rt[curDump].used, 
      rt[curDump].pinned);
    printf(" lu: a %d s %d", 
      call CXRoutingTable.advertiseDistance(rt[curDump].n0, rt[curDump].n1, FALSE),
      call CXRoutingTable.selectionDistance(rt[curDump].n0, rt[curDump].n1, FALSE));
    printf(" rev: a %d s %d\r\n", 
      call CXRoutingTable.advertiseDistance(rt[curDump].n1, rt[curDump].n0, TRUE),
      call CXRoutingTable.selectionDistance(rt[curDump].n1, rt[curDump].n0, TRUE));
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

  command uint8_t CXRoutingTable.advertiseDistance(am_addr_t from, 
      am_addr_t to, bool bdOK){
    cx_max_route_entry_t* re;
    if (from == TOS_NODE_ID && to == TOS_NODE_ID){
      return 0;
    }
    if (getEntry(&re, from, to, bdOK)){
      return re->maxDistance;
    }else{
      return 0xff;
    }
  }

  command uint8_t CXRoutingTable.selectionDistance(am_addr_t from,
    am_addr_t to, bool bdOK){
    cx_max_route_entry_t* re;
    if (from == TOS_NODE_ID && to == TOS_NODE_ID){
      return 0;
    }
    if (getEntry(&re, from, to, bdOK)){
      return re->minDistance;
    }else{
      return 0xff;
    }
  }


  command error_t CXRoutingTable.update(am_addr_t n0, am_addr_t n1,
      uint8_t distance, bool incremental){
    uint8_t i;
    uint8_t checked = 0;
    cx_max_route_entry_t* re;
    uint32_t ts = now();
    if (getEntry(&re, n0, n1, FALSE)){
      //record this if it meets/exceeds current max distance. Replace
      //current max distance if it's expired.
      printf_ROUTING_TABLE("MAX UR %u -> %u M(%u, %lu) m(%u, %lu) => (%u, %lu) =>",
        n0, n1, 
        re->maxDistance, re->lastMax,
        re->minDistance, re->lastMin,
        distance, ts);
      if ( distance >= re->maxDistance || 
        (ts - re->lastMax > CX_ROUTING_TABLE_TIMEOUT) ){
        re->maxDistance = distance;
        re->lastMax = ts;
      } 
      if (distance <= re->minDistance || 
        (ts - re->lastMin > CX_ROUTING_TABLE_TIMEOUT) ){
        re->minDistance = distance;
        re->lastMin = ts;
      } 

      printf_ROUTING_TABLE("M(%u, %lu) m(%u, %lu)\r\n", 
        re->maxDistance, re->lastMax,
        re->minDistance, re->lastMin);
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
    rt[i].minDistance = distance;
    rt[i].lastMin = ts;
    rt[i].maxDistance = distance;
    rt[i].lastMax = ts;
    rt[i].used = TRUE;
    printf_ROUTING_TABLE("MAX NR %u->%u M(%u, %lu) m(%u, %lu)\r\n", 
      n0, n1,
      rt[i].maxDistance, rt[i].lastMax,
      rt[i].minDistance, rt[i].lastMin);
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

