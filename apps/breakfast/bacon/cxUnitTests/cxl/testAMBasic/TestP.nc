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


 #include "test.h"
module TestP{
  uses interface Boot;
  uses interface UartStream;
  uses interface StdControl as SerialControl;

  uses interface LppControl;
  #if CX_BASESTATION == 1
  uses interface CXMacMaster;
  #endif
  uses interface SplitControl;
  uses interface AMSend;
  uses interface Packet;
  uses interface Receive;
  uses interface Pool<message_t>;

  uses interface Leds;
  uses interface LocalTime<TMilli>;

  uses interface Timer<TMilli> as PacketTimer;
} implementation {

  message_t* txMsg;
  message_t* rxMsg;
 
  uint16_t packetQueue = 0;
  uint32_t sn = 0;

  bool started = FALSE;
  task void toggleStartStop();
  
  #define SERIAL_PAUSE_TIME 10240UL



  task void usage(){
    cdbg(APP, "USAGE\r\n");
    cdbg(APP, "-----\r\n");
    cdbg(APP, " q: reset\r\n");
    cdbg(APP, " t: transmit packet\r\n");
    cdbg(APP, " p: toggle probe interval between 1 second and default\r\n");
    cdbg(APP, " s: sleep\r\n");
    cdbg(APP, " w: wakeup\r\n");
    cdbg(APP, " k: kill serial (for 10 seconds)\r\n");
    #if CX_BASESTATION == 1
    cdbg(APP, " [0-9]: issue CTS\r\n");
    #endif
    cdbg(APP, " S: toggle start/stop\r\n");
  }


  event void Boot.booted(){
    call SerialControl.start();
    cdbg(APP, "Booted\r\n");
    post usage();
    atomic{
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
//      //SMCLK to 1.1
      P1MAP1 = PM_SMCLK;
      //GDO to 2.4 (synch)
      P2MAP4 = PM_RFGDO0;
      PMAPPWD = 0x00;

      P1DIR |= BIT1;
      P1SEL &= ~BIT1;
      P1OUT &= ~BIT1;
      P1SEL |= BIT1;
      P2DIR |= BIT4;
      P2SEL |= BIT4;
      
      //power on flash chip
      P2SEL &=~BIT1;
      P2OUT |=BIT1;
      //enable p1.2,3,4 for gpio
      P1DIR |= BIT2 | BIT3 | BIT4;
      P1SEL &= ~(BIT2 | BIT3 | BIT4);
    }
    post toggleStartStop();
  }


  task void sendPacket(){
    if (txMsg){
      cwarn(APP, "still sending\r\n");
    }else{
      uint8_t i;
      test_payload_t* pl;
      error_t err;
      txMsg = call Pool.get();
      call Packet.clear(txMsg);
      pl = call Packet.getPayload(txMsg, 
        sizeof(test_payload_t));
      cdbg(APP, "PL: %p\r\n", pl);
      for (i = 0; i < PAYLOAD_LEN; i++){
        pl->body[i] = i;
      }
      pl->timestamp = sn++;
      err = call AMSend.send(AM_BROADCAST_ADDR, txMsg, sizeof(test_payload_t));
      cinfo(APP, "APP TX %x\r\n", err);
      cdbg(APP, "PLL %u max %u\r\n", 
        call Packet.payloadLength(txMsg), 
        call Packet.maxPayloadLength());
      if (err != SUCCESS){
        call Pool.put(txMsg);
        txMsg = NULL;
      }
    }
  }

  task void sleep(){
    cinfo(APP, "Sleep: %x\r\n", call LppControl.sleep());
  }

  event void PacketTimer.fired(){
    if (packetQueue + 1 != 0){
      packetQueue ++;
    }
    if (packetQueue == 1){
      post sendPacket(); 
    }
  }

  event void SplitControl.startDone(error_t error){ 
    cdbg(APP, "start done: %x pool: %u\r\n", error, call Pool.size());
    started = (error == SUCCESS);

    if (started && PACKET_GEN_RATE){
      call PacketTimer.startPeriodic(PACKET_GEN_RATE);
    }
  }
  event void SplitControl.stopDone(error_t error){ 
    cdbg(APP, "stop done: %x pool: %u\r\n", error, call Pool.size());
    started = FALSE;
  }

  event void AMSend.sendDone(message_t* msg, error_t error){
    call Leds.led0Toggle();
    cinfo(APP, "APP TXD %x\r\n", error);
    cdbg(APP, "post PLL %u\r\n", call Packet.payloadLength(msg));
    if (error == SUCCESS){
      if (packetQueue != 0){
        packetQueue --;
      }
      if (packetQueue){
        post sendPacket();
      }
    }
    if (msg == txMsg){
      call Pool.put(txMsg);
      txMsg = NULL;
    } else{
      cwarn(APP, "mystery packet: %p\r\n", msg);
    }
  }

  task void handleRX(){
    test_payload_t* pl = call Packet.getPayload(rxMsg,
      sizeof(test_payload_t));
    cinfo(APP, "APP RX %p %p %u\r\n", rxMsg, pl, 
      call Packet.payloadLength(rxMsg)); 
    {
      uint8_t i;
      uint8_t* b = (uint8_t*)rxMsg;
      cdbg(APP, "RXP [");
      for (i=0; i < PAYLOAD_LEN; i++){
        cdbg(APP, "%x ", pl->body[i]);
      }
      cdbg(APP, "] %lx\r\n", pl->timestamp);

      cdbg(APP, "RXA [");
      for (i =0; i< sizeof(message_t); i++){
        cdbg(APP, "%x ", b[i]);
      }
      cdbg(APP, "]\r\n");
    }
    call Pool.put(rxMsg);
    rxMsg = NULL;
  }

  event message_t* Receive.receive(message_t* msg, void* pl, uint8_t len){
    if (rxMsg == NULL){
      message_t* ret = call Pool.get();
      if (ret){
        rxMsg = msg;
        post handleRX();
        return ret;
      }else{
        cerror(APP, "pool empty\r\n");
        return msg;
      }
    }else{
      cwarn(APP, "Busy RX\r\n");
      return msg;
    }
  }


  task void toggleStartStop(){
    if (started){
      cdbg(APP, "stopping\r\n");
      call SplitControl.stop();
    }else {
      cdbg(APP, "starting\r\n");
      call SplitControl.start();
    }
  }
  
  task void wakeup(){
    cdbg(APP, "wakeup: %x\r\n", call LppControl.wakeup());
  }

  bool longProbe = TRUE;
  task void setProbeInterval(){
    uint32_t pi;
    error_t error;
    if (longProbe){
      pi = PROBE_INTERVAL;
    }else{
      pi = LPP_DEFAULT_PROBE_INTERVAL;
    }
    error = call LppControl.setProbeInterval(pi);
    if (error == SUCCESS){
      longProbe = (pi == LPP_DEFAULT_PROBE_INTERVAL);
    }
    cdbg(APP, "SPI %lu: %x\r\n", pi, error);
  }
 
  event void LppControl.wokenUp(){
    cdbg(APP, "woke up\r\n");
  }

  event void LppControl.fellAsleep(){
    cdbg(APP, "Fell asleep\r\n");
  }

  #if CX_BASESTATION == 1
  event void CXMacMaster.ctsDone(am_addr_t node, error_t error){
    cinfo(APP, "CTSD: %x %x\r\n", node, error);
  }
  
  norace am_addr_t ctsNode;
  task void sendCts(){
    cinfo(APP, "CTS: %x %x\r\n", ctsNode, 
      call CXMacMaster.cts(ctsNode));
  }
  #endif

  async event void UartStream.receivedByte(uint8_t byte){ 
     switch(byte){
       case 'q':
         WDTCTL = 0;
         break;
       case 't':
         post sendPacket();
         break;
       case 's':
         post sleep();
         break;
       case 'p':
         post setProbeInterval();
         break;
       case 'w':
         post wakeup();
         break;
       case '?':
         post usage();
         break;
       case 'S':
         post toggleStartStop();
         break;
       case '\r':
         printf("\n");
         break;
       #if CX_BASESTATION == 1
       case '0':
       case '1':
       case '2':
       case '3':
       case '4':
       case '5':
       case '6':
       case '7':
       case '8':
       case '9':
         ctsNode = byte - '0';
         post sendCts();
         break;
       #endif
       default:
         break;
     }
     printf("%c", byte);
  }

  async event void UartStream.receiveDone( uint8_t* buf, uint16_t len,
    error_t error ){}
  async event void UartStream.sendDone( uint8_t* buf, uint16_t len,
    error_t error ){}
}
