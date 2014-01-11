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
module SimpleSkewCorrectionP {
  provides interface SkewCorrection;
  uses interface ActiveMessageAddress;
} implementation {

  am_addr_t other = AM_BROADCAST_ADDR;

  uint32_t lastTimestamp = 0;
  uint32_t lastCapture = 0;
  uint32_t lastOriginFrame = 0;

  #define TICK_SCALE (4*1024L)
  //1024 ticks in a frame
  //50ppm error max
  //0.0512 ticks/per frame max
  //*1024 = 52.5 ticks_scaled/per frame
  #define MAX_SKEW (4L*53L)
  int32_t cumulativeTpf_s = 0;

  int32_t lastDelta;
  uint32_t lastFramesElapsed;

  uint32_t selfReferenceFrame = INVALID_TIMESTAMP;
  uint32_t selfReferenceTime = INVALID_FRAME;

  task void printResults(){
    cdbg(SKEW, "SK TPF_s: %li ld: %li over %lu\r\n", 
      cumulativeTpf_s, lastDelta, lastFramesElapsed);
//    cdbg(SKEW, " @20 %li @50 %li @100 %li @1000 %li\r\n",
//      call SkewCorrection.getCorrection(other, 20L),
//      call SkewCorrection.getCorrection(other, 50L),
//      call SkewCorrection.getCorrection(other, 100L),
//      call SkewCorrection.getCorrection(other, 1000L));
  }


  command error_t SkewCorrection.addMeasurement(am_addr_t otherId, 
      bool isSynched, uint32_t otherTS, uint32_t originFrame, 
      uint32_t myTS){
    if (otherId == call ActiveMessageAddress.amAddress()){
      selfReferenceTime = otherTS;
      selfReferenceFrame = originFrame;
      return SUCCESS;
    }else if (otherTS == INVALID_TIMESTAMP || myTS == INVALID_TIMESTAMP 
        || originFrame == INVALID_FRAME || otherTS == lastTimestamp 
        || myTS == lastCapture ){
      return EINVAL;
    }else{
      if (otherId != other){
        //we only track one master: if we switch masters for whatever
        //reason, need to clear it out and start over again.
        //n.b. we let TPF = 0 initially to keep things simple. In
        //general, we should be reasonably close to this. 
        other = otherId;
        lastTimestamp = 0;
        lastCapture = 0;
        lastOriginFrame = 0;
        cumulativeTpf_s = 0;
      }
      if (lastTimestamp != 0 && lastCapture != 0 
          && lastOriginFrame != 0 
          && isSynched && otherTS > lastTimestamp){
        int32_t remoteElapsed_t = (otherTS - lastTimestamp);
        int32_t localElapsed_t = (myTS - lastCapture);
        int32_t framesElapsed = originFrame - lastOriginFrame;
        //positive = we are fast = require shift back = add to wakeup
        //time. Otherwise, we need to negate the result before
        //applying it.
        int32_t delta_s = (localElapsed_t - remoteElapsed_t)*TICK_SCALE;
  
        int32_t tpf_s = delta_s / framesElapsed;
        if ( tpf_s > MAX_SKEW || tpf_s < (-1* MAX_SKEW)){
          cwarn(SKEW, "SE %li : (%lu - %lu) - (%lu - %lu) / %lu\r\n",
            tpf_s,
            myTS, lastCapture,
            otherTS, lastTimestamp, 
            framesElapsed);
        } else {
          //next EWMA step: alpha is fixed at = 0.5
          //the choice of rounding method affects the convergence
          //  behavior, for a given constant skew.

          //rounding method 1: always round down:
          // - will converge to 0 in the absence of skew
          // - will converge to exact skew if negative
          // - will converge to (exact skew - 1) if positive
          // This is probably the safest, as the bias will tend to
          // wake up the radio *early* rather than late.
          int32_t r = 0;

          //method 2: round towards infinity
          // - will converge to exact constant skew (positive and negative)
          // - once perturbed from 0, will never re-converge to 0.
//          int32_t sum = (cumulativeTpf_s + tpf_s);
//          int32_t r = (sum >0 ? 1L: -1L)*(BIT0 & sum);
//          cumulativeTpf_s = ((cumulativeTpf_s + tpf_s)+r) >> 1;
          cumulativeTpf_s = ((cumulativeTpf_s + tpf_s)+r) >> 1;
        }
        //TODO: DEBUG remove
        lastDelta = delta_s;
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
      return (cumulativeTpf_s * framesElapsed)/TICK_SCALE;
    } else {
      return 0;
    }
  }

  async event void ActiveMessageAddress.changed(){ }
  
}
