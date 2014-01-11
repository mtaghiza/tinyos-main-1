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


 #include "phoenix.h"
 #include "phoenixDebug.h"
 #include "multiNetwork.h"
 #include "CXMac.h"
module PhoenixNeighborhoodP {
  uses interface Timer<TMilli>;
  uses interface SettingsStorage;
  uses interface LogWrite;
  uses interface LppProbeSniffer as SubLppProbeSniffer;
  provides interface LppProbeSniffer;
  uses interface Boot;
  uses interface CXLinkPacket;
  uses interface Packet;
  uses interface Get<uint16_t> as RebootCounter;
  uses interface Random;
} implementation {
  phoenix_reference_t ref;
  bool sniffing = FALSE;
 

  //This 2**RAND_RANGE_EXP is the range of values around the mean
  //which our randomized selections may take. So, if this is 8, then
  //our selections will be +/- 128 from the mean.
  #ifndef PHOENIX_RAND_RANGE_EXP
  #define PHOENIX_RAND_RANGE_EXP 8
  #endif

  #define PHOENIX_RAND_RANGE (1 << PHOENIX_RAND_RANGE_EXP)

  #define PHOENIX_RAND_MASK (PHOENIX_RAND_RANGE - 1)
  #define PHOENIX_RAND_OFFSET (PHOENIX_RAND_RANGE >> 1)

  uint32_t randomize(uint32_t mean){
    return (mean - PHOENIX_RAND_OFFSET) + ((call Random.rand32()) & PHOENIX_RAND_MASK ) ;
  }

  void setNext(){
    nx_uint32_t sampleInterval;
    uint32_t nextInterval;
    sampleInterval = DEFAULT_PHOENIX_SAMPLE_INTERVAL;
    call SettingsStorage.get(SS_KEY_PHOENIX_SAMPLE_INTERVAL, 
      &sampleInterval, sizeof(sampleInterval));
    cdbg(PHOENIX, "set next: %lu default %lu\r\n",
      sampleInterval, DEFAULT_PHOENIX_SAMPLE_INTERVAL);
    nextInterval = randomize(sampleInterval);
    call Timer.startOneShot(nextInterval);
  }

  event void Boot.booted(){
    ref.recordType = RECORD_TYPE_PHOENIX;
    setNext();
    //First measurement: shortly after booting
    call Timer.startOneShot(randomize(10240UL));
  }
  
  uint8_t refsCollected;
  uint8_t totalChecks;
  nx_uint8_t targetRefs;
  am_addr_t lastSrc;

  task void sniffAgain(){
    error_t error = call SubLppProbeSniffer.sniff(NS_SUBNETWORK);
    cdbg(PHOENIX, "sniff: %x\r\n", error);
    if (error == SUCCESS){
      sniffing = TRUE;
      //cool. wait until we get a sniffDone.
    } else {
      setNext();
    }
  }

  event void Timer.fired(){
    cdbg(PHOENIX, "phoenix start\r\n");
    targetRefs = DEFAULT_PHOENIX_TARGET_REFS;
    refsCollected = 0;
    totalChecks = 0;
    lastSrc = AM_BROADCAST_ADDR;
    call SettingsStorage.get(SS_KEY_PHOENIX_TARGET_REFS, 
      &targetRefs, sizeof(targetRefs));
    post sniffAgain();
  }
  
  bool appending = FALSE;
  task void logReference(){
    cdbg(PHOENIX, "Logging (%x, (%u, %lu), (%u, %lu))\r\n",
      ref.node2, ref.rc1, ref.localTime1, ref.rc2, ref.localTime2);
    if ( call LogWrite.append(&ref, sizeof(ref)) == SUCCESS){
      appending = TRUE;
    }
  }

  event void LogWrite.appendDone(void* buf, storage_len_t len, 
      bool recordsLost, error_t error){
    appending = FALSE;
  }

//  uint32_t toMilli(uint32_t t32k){
//    uint32_t milli = call Timer.getNow()
//    //if msb(32k) is set, but corresponding bit in milli is clear,
//    //then 32k time has rolled over between ts assignment and now.
//    if ( (t32k & (1UL << 31)) & ((t32k & (1UL << 31) ) ^ ((milli << 5) & (1UL << 31)))){ 
//      milli -= (1UL << 27);
//    }  
//    return (milli & ((BIT1|BIT2|BIT3|BIT4|BIT5) << 27)) | (t32k >> 5);
//  }

  event message_t* SubLppProbeSniffer.sniffProbe(message_t* msg){
    if (sniffing){
      cx_lpp_probe_t* pl = call Packet.getPayload(msg,
        sizeof(cx_lpp_probe_t));
      refsCollected++;
      cdbg(PHOENIX, "probe %p from %x @(%u, %lu): (%u, %lu)\r\n", 
        msg, call CXLinkPacket.source(msg),
        call RebootCounter.get(),
        (call CXLinkPacket.getLinkMetadata(msg))->timeMilli,
        pl->rc,
        pl->tMilli);
      if (! appending && call CXLinkPacket.source(msg) != lastSrc){
        lastSrc = call CXLinkPacket.source(msg);
        ref.rc1 = call RebootCounter.get();
        ref.localTime1 = (call CXLinkPacket.getLinkMetadata(msg))->timeMilli;
        ref.node2 = lastSrc;
        ref.rc2 = pl->rc;
        ref.localTime2 = pl->tMilli;
        post logReference();
      }else {
        cdbg(PHOENIX, "ignore\r\n");
      }
    }
    return signal LppProbeSniffer.sniffProbe(msg);
  }

  command error_t LppProbeSniffer.sniff(uint8_t ns){
    return FAIL;
  }

  event void SubLppProbeSniffer.sniffDone(error_t error){
    totalChecks++;
    cdbg(PHOENIX, "sniff done %u %u %u %u\r\n", 
      refsCollected, targetRefs, totalChecks, MAX_WASTED_SNIFFS);
    if (refsCollected < targetRefs && totalChecks < targetRefs + MAX_WASTED_SNIFFS){
      post sniffAgain();
    }else{
      sniffing = FALSE;
      setNext();
    }
  }

  event void LogWrite.syncDone(error_t error){ }
  event void LogWrite.eraseDone(error_t error){ }
}
