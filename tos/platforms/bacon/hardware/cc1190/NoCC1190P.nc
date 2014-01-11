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

module NoCC1190P{
  provides interface Init;
  provides interface StdControl;
  provides interface CC1190;
  uses interface GeneralIO as HGMPin;
  uses interface GeneralIO as LNA_ENPin;
  uses interface GeneralIO as PA_ENPin;
  uses interface GeneralIO as PowerPin;
} implementation {
  command error_t Init.init(){ 
    call HGMPin.makeOutput();
    call HGMPin.clr();
    call LNA_ENPin.makeOutput();
    call LNA_ENPin.makeOutput();
    call PA_ENPin.clr();
    call PA_ENPin.clr();
    call PowerPin.makeOutput();
    call PowerPin.clr();
    return SUCCESS; 
  }
  command error_t StdControl.start(){ return SUCCESS;}
  command error_t StdControl.stop(){ return SUCCESS;}
  command void CC1190.RXMode(uint8_t hgm){}
  command void CC1190.TXMode(uint8_t hgm){}
}
