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

generic configuration Rf1aPhysicalLogC (){
  provides interface Rf1aPhysical;

  provides interface DelayedSend;
  provides interface RadioStateLog;

  provides interface Rf1aPhysicalMetadata;
  uses interface Rf1aTransmitFragment;
  uses interface Rf1aConfigure;
  provides interface Resource;
  provides interface Rf1aStatus;
} implementation {
  components Rf1aPhysicalLogP;
  components new Rf1aPhysicalC();

  Rf1aPhysical = Rf1aPhysicalLogP.Rf1aPhysical;
  Rf1aPhysicalLogP.SubRf1aPhysical -> Rf1aPhysicalC;

//  DelayedSend = Rf1aPhysicalC;
  DelayedSend = Rf1aPhysicalLogP.DelayedSend;
  Rf1aPhysicalLogP.SubDelayedSend -> Rf1aPhysicalC.DelayedSend;

  RadioStateLog = Rf1aPhysicalLogP;
  components LocalTime32khzC;
  Rf1aPhysicalLogP.LocalTime -> LocalTime32khzC;
  
  Rf1aPhysicalMetadata = Rf1aPhysicalC;
  Rf1aTransmitFragment = Rf1aPhysicalC;
  Rf1aConfigure = Rf1aPhysicalC;
  Resource = Rf1aPhysicalC;
  Rf1aStatus = Rf1aPhysicalC;

}
