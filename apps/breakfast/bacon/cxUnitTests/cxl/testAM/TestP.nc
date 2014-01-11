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
  uses interface UartStream;
  uses interface StdControl as SerialControl;

  uses interface SplitControl;
  uses interface AMSend as GlobalAMSend;
  uses interface AMSend as SubNetworkAMSend;
  uses interface AMSend as RouterAMSend;
  uses interface Packet;
  uses interface CXLinkPacket;
  uses interface Receive;
  uses interface Pool<message_t>;
  
  #if CX_BASESTATION == 1
  uses interface CXDownload as GlobalCXDownload;
  uses interface CXDownload as RouterCXDownload;
  #endif

  #if CX_ROUTER == 1
  uses interface CXDownload as SubNetworkCXDownload;
  #endif
  uses interface Leds;
} implementation {

  message_t* globalMsg;
  message_t* subNetworkMsg;
  message_t* routerMsg;
  message_t* rxMsg;

  norace uint8_t txSegment;

  bool started = FALSE;
  bool continuousSend;
  task void toggleStartStop();
  
  #ifndef PAYLOAD_LEN 
  #define PAYLOAD_LEN 10
  #endif
  #define SERIAL_PAUSE_TIME 10240UL


  task void usage(){
    #if CX_BASESTATION == 1
    printf("BASESTATION USAGE (node %x)\r\n", TOS_NODE_ID); 
    #elif CX_ROUTER == 1
    printf("ROUTER USAGE (node %x)\r\n", TOS_NODE_ID); 
    #else
    printf("LEAF USAGE (node %x)\r\n", TOS_NODE_ID); 
    #endif

    printf("-----\r\n");
    printf(" q: reset\r\n");

    printf(" g: transmit packet on global segment\r\n");
    #if CX_BASESTATION == 1
    printf(" G: download from global segment\r\n");
    #endif
    printf(" s: transmit packet on subnetwork segment\r\n");
    #if CX_ROUTER == 1 
    printf(" S: download from subnetwork segment\r\n");
    printf(" r: transmit packet on router segment\r\n");
    #endif
    #if CX_BASESTATION == 1
    printf(" R: download from router segment\r\n");
    #endif
    printf(" T: toggle continuous transmission\r\n");
    printf(" k: kill serial (for 10 seconds)\r\n");
    printf("=====\r\n");
    printf("Pool: %u\r\n", call Pool.size());
  }


  event void Boot.booted(){
    call SerialControl.start();
    printf("Booted\r\n");
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
  
  task void toggleContinuous(){
    continuousSend = !continuousSend;
  }

  task void sendPacket(){
    cx_link_header_t* header;
    test_payload_t* pl;
    error_t err;
    switch (txSegment){
      case NS_GLOBAL:
        globalMsg = call Pool.get();
        call Packet.clear(globalMsg);
        err = call GlobalAMSend.send(TEST_DESTINATION, 
          globalMsg, call Packet.maxPayloadLength());
        if (err != SUCCESS){
          call Pool.put(globalMsg);
          globalMsg = NULL;
        }
        break;
      case NS_SUBNETWORK:
        subNetworkMsg = call Pool.get();
        call Packet.clear(subNetworkMsg);
        err = call SubNetworkAMSend.send(TEST_DESTINATION, 
          subNetworkMsg, call Packet.maxPayloadLength());
        if (err != SUCCESS){
          call Pool.put(subNetworkMsg);
          subNetworkMsg = NULL;
        }
        break;
      case NS_ROUTER:
        routerMsg = call Pool.get();
        call Packet.clear(routerMsg);
        err = call RouterAMSend.send(TEST_DESTINATION, 
          routerMsg, call Packet.maxPayloadLength());
        if (err != SUCCESS){
          call Pool.put(routerMsg);
          routerMsg = NULL;
        }
        break;
        
    }
    printf("APP TX %x\r\n", err);
  }

  event void SplitControl.startDone(error_t error){ 
    printf("start done: %x pool: %u\r\n", error, call Pool.size());
    started = (error == SUCCESS);
  }
  event void SplitControl.stopDone(error_t error){ 
    printf("stop done: %x pool: %u\r\n", error, call Pool.size());
    started = FALSE;
  }

  void doSendDone(message_t* msg, error_t error){
    call Leds.led0Toggle();
    printf("APP TXD %x\r\n", error);
    if (continuousSend){
      post sendPacket();
    }
  }

  event void GlobalAMSend.sendDone(message_t* msg, error_t error){
    printf("GS.SD\r\n");
    doSendDone(msg, error);   
    call Pool.put(globalMsg);
    globalMsg = NULL;
  }

  event void SubNetworkAMSend.sendDone(message_t* msg, error_t error){
    printf("SNS.SD\r\n");
    doSendDone(msg, error);   
    call Pool.put(subNetworkMsg);
    subNetworkMsg = NULL;
  }

  event void RouterAMSend.sendDone(message_t* msg, error_t error){
    printf("RS.SD\r\n");
    doSendDone(msg, error);   
    call Pool.put(routerMsg);
    routerMsg = NULL;
  }

  task void handleRX(){
    test_payload_t* pl = call Packet.getPayload(rxMsg,
      sizeof(test_payload_t));
    printf("APP RX %p %p\r\n", rxMsg, pl); 
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
        printf("pool empty\r\n");
        return msg;
      }
    }else{
      printf("Busy RX\r\n");
      return msg;
    }
  }


  task void toggleStartStop(){
    if (started){
      call SplitControl.stop();
    }else {
      call SplitControl.start();
    }
  }
  
  #if CX_BASESTATION == 1
  task void downloadGlobal(){
    printf("Global Download %x\r\n", 
      call GlobalCXDownload.startDownload());
  }
  event void GlobalCXDownload.downloadFinished(){
    printf("Global Download finished\r\n");
  }

  task void downloadRouter(){
    printf("Router Download %x\r\n", 
      call RouterCXDownload.startDownload());
  }
  event void RouterCXDownload.downloadFinished(){
    printf("Router Download finished\r\n");
  }
  #endif

  #if CX_ROUTER == 1
  task void downloadSubNetwork(){
    printf("SubNetwork Download %x\r\n", 
      call SubNetworkCXDownload.startDownload());
  }
  event void SubNetworkCXDownload.downloadFinished(){
    printf("SubNetwork Download finished\r\n");
  }
  #endif


  async event void UartStream.receivedByte(uint8_t byte){ 
     switch(byte){
       case 'q':
         WDTCTL = 0;
         break;
       case 'g':
         txSegment = NS_GLOBAL;
         post sendPacket();
         break;

       #if CX_BASESTATION == 1
       case 'G':
         post downloadGlobal();
         break;
       #endif

       case 's':
         txSegment = NS_SUBNETWORK;
         post sendPacket();
         break;

       #if CX_ROUTER == 1
       case 'S':
         post downloadSubNetwork();
         break;
       #endif

       case 'r':
         txSegment = NS_ROUTER;
         post sendPacket();
         break;

       #if CX_BASESTATION == 1
       case 'R':
         post downloadRouter();
         break;
       #endif

       case 'T':
         post toggleContinuous();
         post sendPacket();
         break;
       case '?':
         post usage();
         break;
       case '\r':
         printf("\n");
         break;
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
