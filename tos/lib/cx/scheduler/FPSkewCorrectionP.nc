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


 #include "fixedPointUtils.h"
 #include "CXSchedulerDebug.h"
 #include "CXNetwork.h"
 #include "CXScheduler.h"
 #include "SkewCorrection.h"
module FPSkewCorrectionP {
  provides interface SkewCorrection;
} implementation {

  am_addr_t other = AM_BROADCAST_ADDR;

  uint32_t lastTimestamp = 0;
  uint32_t lastCapture = 0;
  uint32_t lastOriginFrame = 0;
  int32_t cumulativeTpf = 0;

  int32_t alpha = FP_1 / SKEW_EWMA_ALPHA_INVERSE;
  int32_t lastDelta;
  uint32_t lastFramesElapsed;

  uint32_t selfReferenceFrame = INVALID_TIMESTAMP;
  uint32_t selfReferenceTime = INVALID_FRAME;

  task void printResults(){
    cdbg(SKEW, " Cumulative TPF: 0x%lx last delta: %li over %lu\r\n", 
      cumulativeTpf, lastDelta, lastFramesElapsed);
    cdbg(SKEW, "  @50 %li @51 %li @100 %li @200 %li @300 %li @320 %li @400 %li @500 %li @1000 %li\r\n",
      stoInt(cumulativeTpf*50),
      stoInt(cumulativeTpf*51),
      stoInt(cumulativeTpf*100),
      stoInt(cumulativeTpf*200),
      stoInt(cumulativeTpf*300),
      stoInt(cumulativeTpf*320),
      stoInt(cumulativeTpf*400),
      stoInt(cumulativeTpf*500),
      stoInt(cumulativeTpf*1000));
  }


  command error_t SkewCorrection.addMeasurement(am_addr_t otherId, 
      bool isSynched, uint32_t otherTS, uint32_t originFrame, 
      uint32_t myTS){
    printf("add\r\n");
    if (otherId == call ActiveMessageAddress.amAddress()){
      printf("self\r\n");
      selfReferenceTime = otherTS;
      selfReferenceFrame = originFrame;
      return SUCCESS;
    }else if (otherTS == INVALID_TIMESTAMP || myTS == INVALID_TIMESTAMP 
        || originFrame == INVALID_FRAME || otherTS == lastTimestamp 
        || myTS == lastCapture ){
      printf("inval\r\n");
      return EINVAL;
    }else{
      printf("other\r\n");
      if (otherId != other){
        printf("new\r\n");
        //we only track one master: if we switch masters for whatever
        //reason, need to clear it out and start over again.
        other = otherId;
        lastTimestamp = 0;
        lastCapture = 0;
        lastOriginFrame = 0;
        cumulativeTpf = 0;
      }
      if (lastTimestamp != 0 && lastCapture != 0 
          && lastOriginFrame != 0 
          && isSynched && otherTS > lastTimestamp){
        int32_t remoteElapsed = otherTS - lastTimestamp;
        int32_t localElapsed = myTS - lastCapture;
        int32_t framesElapsed = originFrame - lastOriginFrame;
        //positive = we are fast = require shift back = add to wakeup
        //time. Otherwise, we need to negate the result before
        //applying it.
        int32_t delta = localElapsed - remoteElapsed;
        //this is fixed point, TPF_DECIMAL_PLACES bits after decimal
        int32_t deltaFP = (delta << TPF_DECIMAL_PLACES);
  
        int32_t tpf = deltaFP / framesElapsed;
        if ( (tpf > 0 && tpf > MAX_VALID_TPF) 
            || (tpf < 0 && (-1L*tpf) > MAX_VALID_TPF)){
          cwarn(SKEW, "SKEW EXCEEDED\r\n");
        } else {
          //next EWMA step
          //n.b. we let TPF = 0 initially to keep things simple. In
          //general, we should be reasonably close to this. 
//          cdbg(SKEW, "CTPF %lx ->", cumulativeTpf);
          cumulativeTpf = sfpMult(cumulativeTpf, (FP_1 - alpha)) 
            + sfpMult(tpf, alpha);
//          cdbg(SKEW, "%lx\r\n", cumulativeTpf);
        }
        //TODO: DEBUG remove
        lastDelta = delta;
        lastFramesElapsed = framesElapsed;
        post printResults();
      }
      lastTimestamp = otherTS;
      lastCapture = myTS;
      lastOriginFrame = originFrame;
      return SUCCESS;
    }
  }

  command uint32_t SkewCorrection.referenceFrame(am_addr_t otherId){
    if (otherId == other && lastOriginFrame != INVALID_FRAME)
    {
      return lastOriginFrame;
    }else if (otherId == call ActiveMessageAddress.amAddress()){
      return selfReferenceFrame;
    } else {
      return INVALID_FRAME;
    }
  }

  command uint32_t SkewCorrection.referenceTime(am_addr_t otherId){
    if (otherId == other && lastCapture != INVALID_TIMESTAMP)
    {
      return lastCapture;
    } else if (otherId == call ActiveMessageAddress.amAddress()){
      return selfReferenceTime;
    }else{
      return INVALID_TIMESTAMP;
    }
  }

  command int32_t SkewCorrection.getCorrection(am_addr_t otherId, 
      int32_t framesElapsed){
    if (otherId == other){
      return stoInt(cumulativeTpf*framesElapsed);
    } else {
      return 0;
    }
  }
  
}
