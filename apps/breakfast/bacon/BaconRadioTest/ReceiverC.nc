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

#include "bacon_radio_test.h"

configuration ReceiverC{
} implementation {
  components ReceiverP as Test;

  components MainC;
  Test.Boot -> MainC;
  
  components LedsC;
  Test.Leds -> LedsC;

  components ActiveMessageC;
  Test.SplitControl -> ActiveMessageC;
  Test.RadioPacket -> ActiveMessageC;

  components new AMReceiverC(AM_TXRX);
  Test.Receive -> AMReceiverC;

#ifdef HAS_CC1190
  components CC1190C;
  Test.CC1190 -> CC1190C;
  Test.CC1190Control -> CC1190C;
#endif
  components SerialActiveMessageC;
  Test.SerialSplitControl -> SerialActiveMessageC;
  Test.SerialPacket -> SerialActiveMessageC;
  components new SerialAMSenderC(AM_REPORT);
  Test.ReportSend -> SerialAMSenderC;

  components Rf1aActiveMessageC;
  Test.Rf1aPacket -> Rf1aActiveMessageC;

  

}
