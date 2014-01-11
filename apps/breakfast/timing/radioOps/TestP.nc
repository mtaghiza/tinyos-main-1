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

module TestP {
  uses {
    interface Boot;
    interface AMSend;
    interface SplitControl;
    interface Packet;
    interface HplMsp430GeneralIO as MarkerPin;
    interface HplMsp430GeneralIO as TimerPin;
    interface Timer<TMilli> as StartPauseTimer;
    interface Timer<TMilli> as SendPauseTimer;
    interface Timer<TMilli> as StopPauseTimer;
    interface Leds;
  }
}
implementation {
  message_t m;

  event void Boot.booted() {
    call TimerPin.makeOutput();
    call TimerPin.set();
    call MarkerPin.makeOutput();
    call MarkerPin.clr();
    call StartPauseTimer.startOneShot(TEST_INTERVAL);
    //this turns off all leds on the surf platform (when a bacon binary is on it)
    call Leds.set(7);
    //call Leds.set(1);
  }
   
  event void StartPauseTimer.fired() {
    call TimerPin.clr();
    call MarkerPin.set();
    call MarkerPin.clr();
    call SplitControl.start();
    //call Leds.set(2);
  }

  event void SplitControl.startDone(error_t err) {
    //call Leds.set(3);
    call SendPauseTimer.startOneShot(SEND_PAUSE);
  }
  task void doSend() {
    error_t e;
    //call Leds.set(4);
    e = call AMSend.send(AM_BROADCAST_ADDR, &m, PACKET_SIZE);
    //printf("AMSend.send: %d\n", e);
    //printfflush();
    if (e != SUCCESS) {
      post doSend();
    }
  }
  event void SendPauseTimer.fired() {
    post doSend();
  }

  event void AMSend.sendDone(message_t *msg, error_t err) {
    //call Leds.set(5);
    call StopPauseTimer.startOneShot(STOP_PAUSE);
  }

  event void StopPauseTimer.fired() {
    //call Leds.set(6);
    call SplitControl.stop();
  }

  event void SplitControl.stopDone(error_t err) {
    //call Leds.set(7);
    //call Leds.led0Toggle();
    call TimerPin.set();
    call StartPauseTimer.startOneShot(TEST_INTERVAL);
  }

  
}
