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

//TODO: AM ID for glossy should be fixed, it should encapsulate an
//entire other AM header. So, this should be singleton and should
//just dispatch to relevant client as needed? hm.

generic configuration AMGlossyC(am_id_t AMId){
  provides interface AMSend;
  provides interface AMPacket;
  provides interface Receive;
} implementation {
  components new DelayedAMSenderC(AMId);
  components new AMReceiverC(AMId);
  components new AlarmMicro16C();
  
  components Rf1aActiveMessageC;

  components new AMGlossyP();
  AMGlossyP.DelayedSend -> DelayedAMSenderC.DelayedSend;
  AMGlossyP.SubAMSend -> DelayedAMSenderC.AMSend;
  AMGlossyP.SendNotifier -> DelayedAMSenderC.SendNotifier;
  AMGlossyP.SubReceive -> AMReceiverC;
  AMGlossyP.SubAMPacket -> Rf1aActiveMessageC;
  AMGlossyP.Alarm -> AlarmMicro16C;
  
  //TODO: if there are multiple AMGlossyC's, they'll all be wired to the
  //  same rf1aphysical interface. 
  //  Kept Rf1aCoreInterrupt the same for consistency (since they both
  //  basically just expose the core interrupts)
  AMGlossyP.Rf1aPhysical -> Rf1aActiveMessageC;
  AMGlossyP.Rf1aCoreInterrupt -> Rf1aActiveMessageC;

  AMSend = AMGlossyP.AMSend;
  AMPacket = AMGlossyP.AMPacket;
  Receive = AMGlossyP.Receive;
  
}
