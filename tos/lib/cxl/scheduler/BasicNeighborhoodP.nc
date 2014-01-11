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
      //add them to the neighborhood if we are still filling it 
      // OR 
      //use the position in the neighbor table to determine how likely
      //  we are to evict from it. This is because nodes which are
      //  woken up early in the process are most at risk for eviction
      //  (because there are only a few others that know about them
      //  AND those nodes will be likely to hear lots more probes
      //  (since they woke up in the beginning of the process when
      //  there's tons of dudes still probing))
      if (numNeighbors < CX_NEIGHBORHOOD_SIZE ){
        //new
        cdbg(SCHED, "N %u %u\r\n", neighborIndex, src);
        neighbors[neighborIndex] = src;
      }else{
        //This ensures that the first probe you hear cannot be
        //  evicted. This is
        //  important, because otherwise there is a 50% chance that 
        //  the base station will drop the first node it hears and
        //  that node will not be contacted.
        if((call Random.rand16()%CX_NEIGHBORHOOD_SIZE ) < neighborIndex){
          //evict
          cdbg(SCHED, "E %u %u -> %u\r\n", neighborIndex, neighbors[neighborIndex], src);
          neighbors[neighborIndex] = src;
        }else{
          //drop
          cdbg(SCHED, "D %u\r\n", src);
        }
      }
      neighborIndex = (neighborIndex + 1) % CX_NEIGHBORHOOD_SIZE;
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
