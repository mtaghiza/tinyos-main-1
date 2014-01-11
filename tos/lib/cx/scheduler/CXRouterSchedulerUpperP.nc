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

module CXRouterSchedulerUpperP {
  provides interface CXRequestQueue;
  provides interface SplitControl;

  uses interface SplitControl as MasterSplitControl;
  uses interface SplitControl as SlaveSplitControl;

  uses interface CXRequestQueue as MasterCXRQ;
  uses interface CXRequestQueue as SlaveCXRQ;
  provides interface Get<bool> as GetSlaveMode;
} implementation {
  
  bool slaveMode = TRUE;

  command error_t SplitControl.start(){
    return call SlaveSplitControl.start();
  }

  event void SlaveSplitControl.startDone(error_t error){
    if (error != SUCCESS){
      signal SplitControl.startDone(error);
    }else{
      error = call MasterSplitControl.start();
      if (error != SUCCESS){
        call SlaveSplitControl.stop();
        signal SplitControl.startDone(error);
      }
    }
  }
  event void MasterSplitControl.startDone(error_t error){
    signal SplitControl.startDone(error);
  }
  
  command error_t SplitControl.stop(){
    return call MasterSplitControl.stop();
  }

  event void MasterSplitControl.stopDone(error_t error){
    if (error != SUCCESS){
      signal SplitControl.stopDone(error);
    }else{
      error = call SlaveSplitControl.stop();
      if (error != SUCCESS){
        signal SplitControl.stopDone(error);
      }
    }
  }

  event void SlaveSplitControl.stopDone(error_t error){
    signal SplitControl.stopDone(error);
  }

  command bool GetSlaveMode.get(){
    return slaveMode;
  }
  
  //TODO: some mechanism to detect when we change from master to slave
  //mode: should be a signal at the end of the active period.
  
  command uint32_t CXRequestQueue.nextFrame(bool isTX){
    if (slaveMode){
      return call SlaveCXRQ.nextFrame(isTX);
    }else{
      return call MasterCXRQ.nextFrame(isTX);
    }
  }

  command error_t CXRequestQueue.requestReceive(uint8_t layerCount,
      uint32_t baseFrame, 
      int32_t frameOffset, 
      bool useMicro, uint32_t microRef,
      uint32_t duration, 
      void* md, message_t* msg){
    if (slaveMode){
      return call SlaveCXRQ.requestReceive(layerCount + 1, 
        baseFrame, frameOffset, useMicro, microRef, 
        duration, md, msg);
    } else {
      return call MasterCXRQ.requestReceive(layerCount + 1, 
        baseFrame, frameOffset, useMicro, microRef, 
        duration, md, msg);
    }
  }

  command error_t CXRequestQueue.requestSend(uint8_t layerCount, 
      uint32_t baseFrame, int32_t frameOffset, 
      tx_priority_t txPriority,
      bool useMicro, uint32_t microRef, 
      void* md, message_t* msg){
    if (slaveMode){
      return call SlaveCXRQ.requestSend(layerCount + 1, 
        baseFrame, frameOffset, txPriority,
        useMicro, microRef, md, msg);
    } else {
      return call MasterCXRQ.requestSend(layerCount + 1, 
        baseFrame, frameOffset, txPriority,
        useMicro, microRef, md, msg);
    }
  }

  command error_t CXRequestQueue.requestSleep(uint8_t layerCount,
      uint32_t baseFrame, int32_t frameOffset){
    if (slaveMode){
      return call SlaveCXRQ.requestSleep(layerCount + 1, baseFrame,
        frameOffset);
    } else {
      return call MasterCXRQ.requestSleep(layerCount + 1, baseFrame,
        frameOffset);
    }
  }

  command error_t CXRequestQueue.requestWakeup(uint8_t layerCount, 
    uint32_t baseFrame, int32_t frameOffset,
    uint32_t refFrame, uint32_t refTime, int32_t correction){
    if (slaveMode){
      return call SlaveCXRQ.requestWakeup(layerCount + 1, baseFrame,
        frameOffset, refFrame, refTime, correction);
    } else {
      return call MasterCXRQ.requestWakeup(layerCount + 1, baseFrame,
        frameOffset, refFrame, refTime, correction);
    }
  }

  event void SlaveCXRQ.receiveHandled(error_t error, 
      uint8_t layerCount, 
      uint32_t atFrame, uint32_t reqFrame, 
      bool didReceive, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    signal CXRequestQueue.receiveHandled(error, layerCount - 1, 
      atFrame, reqFrame, didReceive, microRef, t32kRef, md, msg);
  }

  event void SlaveCXRQ.sendHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    signal CXRequestQueue.sendHandled(error, layerCount - 1, atFrame,
      reqFrame, microRef, t32kRef, md, msg);
  }

  event void SlaveCXRQ.sleepHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame){
    signal CXRequestQueue.sleepHandled(error, layerCount - 1, atFrame,
      reqFrame);
  }

  event void SlaveCXRQ.wakeupHandled(error_t error, 
      uint8_t layerCount, 
      uint32_t atFrame, uint32_t reqFrame){
    signal CXRequestQueue.wakeupHandled(error, layerCount - 1,
      atFrame, reqFrame);
  }

  event void MasterCXRQ.receiveHandled(error_t error, 
      uint8_t layerCount, 
      uint32_t atFrame, uint32_t reqFrame, 
      bool didReceive, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    signal CXRequestQueue.receiveHandled(error, layerCount - 1, 
      atFrame, reqFrame, didReceive, microRef, t32kRef, md, msg);
  }

  event void MasterCXRQ.sendHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    signal CXRequestQueue.sendHandled(error, layerCount - 1, atFrame,
      reqFrame, microRef, t32kRef, md, msg);
  }

  event void MasterCXRQ.sleepHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame){
    signal CXRequestQueue.sleepHandled(error, layerCount - 1, atFrame,
      reqFrame);
  }

  event void MasterCXRQ.wakeupHandled(error_t error, 
      uint8_t layerCount, 
      uint32_t atFrame, uint32_t reqFrame){
    signal CXRequestQueue.wakeupHandled(error, layerCount - 1,
      atFrame, reqFrame);
  }


}
