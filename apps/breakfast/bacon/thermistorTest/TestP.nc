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

module TestP{
  uses interface Boot;
  uses interface Leds;
  uses interface UartStream;
  uses interface StdControl as UartControl;
  uses interface Read<uint16_t>;
  uses interface Timer<TMilli>;
  uses interface SplitControl ;
} implementation {
  bool keepSampling = FALSE;

  event void SplitControl.startDone(error_t err){
    printf("StartDone\n\r");
  }

  event void SplitControl.stopDone(error_t err){
    printf("StopDone\n\r");
  }

  event void Boot.booted(){
    call UartControl.start();
    call SplitControl.start();
    printf("\n\rThermistor test\n\r");
    printf("s: Sample\n\r");
    printf("v: toggle power(start/stop)\n\r");
    printf("q: quit/reset\n\r");
  }

  task void sample(){
    printf("Read: %x\n\r", call Read.read());
  }

  task void startSample(){
    printf("Sampling. \n\r");
    keepSampling = TRUE;
    post sample();
  }

  task void stopSample(){
    printf("stop sampling.\n\r");
    keepSampling = FALSE;
    post sample();
  }

  event void Timer.fired(){
    if (keepSampling){
      post sample();
    } else{
      printf("Skip.\n\r");
    }
  }

  event void Read.readDone(error_t err, uint16_t val){
    printf("X R: %x VCC: %x P2.5DIR: %x P2.5SEL: %x P2MAP4: %x Value: %d\n\r", err, 
      0x01 & (PJDIR >>1), 
      0x01 & (P2DIR >>5), 0x01 & (P2SEL >> 5),
      P2MAP4,
      val);
    call Timer.startOneShot(2048);
  }

  async event void UartStream.receivedByte(uint8_t b){
    switch(b){
      case 'q':
        WDTCTL = 0;
        break;
      case 's':
        post startSample();
        break;
      case 'S':
        post stopSample();
        break;
      case 'v':
        if (call SplitControl.start() == EALREADY){
          call SplitControl.stop();
        }
        break;
      case '\r':
        printf("\n\r");
        break;
      default:
        printf("%c", b);
    }
  }
  async event void UartStream.sendDone(uint8_t* buf, uint16_t len, error_t err){}
  async event void UartStream.receiveDone(uint8_t* buf, uint16_t len, error_t err){}

}
