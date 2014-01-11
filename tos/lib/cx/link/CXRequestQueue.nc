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


 #include "message.h"
 #include "requestQueue.h"
interface CXRequestQueue{
  //for all requestX/XHandled functions,
  //  Layer count is 0 at the original request layer. Each down-call
  //  should increment layer count, each up-call should decrement it.
  //  e.g. if we have AM -> transport -> scheduler -> network -> link,
  //  an ACK send request initiated at transport layer would show up
  //  as layerCount 0 at scheduler.requestSend, 1 at network, and 2 at
  //  link (where it's enqueued). When the request is handled, it will
  //  have layerCount == 0 at transport, which will handle it locally
  //  (rather than passing it up to AM).

  //return the next available frame, according to this layer. A return
  //value of 0 indicates "no valid next frame, try again later"
  //This can happen, for instance, if we were not assigned any slots
  //in the current schedule.
  command uint32_t nextFrame(bool isTX);
  
  //specifying duration of 0 means "use whatever default is
  //appropriate" e.g. if we are not synched, the scheduler will set
  //this to some huge value.
  command error_t requestReceive(uint8_t layerCount,
    uint32_t baseFrame, 
    int32_t frameOffset, 
    bool useMicro, uint32_t microRef,
    uint32_t duration, 
    void* md, message_t* msg);

  event void receiveHandled(error_t error, 
    uint8_t layerCount, 
    uint32_t atFrame, uint32_t reqFrame, 
    bool didReceive, 
    uint32_t microRef, uint32_t t32kRef,
    void* md, message_t* msg); 
  
  //N.B.: generally, if you need something sent based on a previous
  // capture event, you should request the send from the *handled
  // event. Otherwise, there's a possibility that the timer will be
  // shut off at the completion of the *handled event.
  command error_t requestSend(uint8_t layerCount, 
    uint32_t baseFrame, int32_t frameOffset, 
    tx_priority_t txPriority,
    bool useMicro, uint32_t microRef, 
    void* md, message_t* msg);

  event void sendHandled(error_t error, 
    uint8_t layerCount,
    uint32_t atFrame, uint32_t reqFrame, 
    uint32_t microRef, uint32_t t32kRef,
    void* md, message_t* msg);

  command error_t requestSleep(uint8_t layerCount,
    uint32_t baseFrame, int32_t frameOffset);
  event void sleepHandled(error_t error, 
    uint8_t layerCount,
    uint32_t atFrame, uint32_t reqFrame);

  command error_t requestWakeup(uint8_t layerCount, 
    uint32_t baseFrame, int32_t frameOffset,
    uint32_t refFrame, uint32_t refTime, int32_t correction);
  event void wakeupHandled(error_t error, 
    uint8_t layerCount, 
    uint32_t atFrame, uint32_t reqFrame);

}
