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


 #include "CXScheduler.h"
configuration CXSchedulerC{
  provides interface CXRequestQueue;
  provides interface SplitControl;
  provides interface Packet; 
  provides interface SlotTiming;
} implementation {
  #if CX_STATIC_SCHEDULE == 1
    #warning "Using static scheduler: TEST ONLY"
    #if CX_MASTER == 1
    components CXMasterSchedulerStaticC as CXScheduler;
    #else
    components CXSlaveSchedulerStaticC as CXScheduler;
    #endif
  #else
    #if CX_ROUTER == 1
      components CXRouterSchedulerC as CXScheduler;
    #else 
      #if CX_MASTER == 1
      components CXMasterSchedulerC as CXScheduler;
      #else
      components CXSlaveSchedulerC as CXScheduler;
      #endif
    #endif
  #endif
  
  CXRequestQueue = CXScheduler;
  SplitControl = CXScheduler;
  Packet = CXScheduler;
  SlotTiming = CXScheduler;
}
