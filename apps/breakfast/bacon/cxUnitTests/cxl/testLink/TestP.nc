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
  uses interface CXLink;
  uses interface Send;
  uses interface Packet;
  uses interface CXLinkPacket;
  uses interface MessageRssi;
  uses interface MessageLqi;
  uses interface Receive;
  uses interface Pool<message_t>;
  uses interface Timer<TMilli>;
  uses interface Timer<TMilli> as RetransmitTimer;

  uses interface Leds;
  uses interface Rf1aStatus;
} implementation {

  message_t* txMsg;
  message_t* rxMsg;

  uint8_t packetLength = PACKET_LENGTH;
  uint8_t channel = CHANNEL;
  bool repeat = REPEAT;

  bool repeatRX = TRUE;

  bool started = FALSE;
  task void toggleStartStop();
  
  #ifndef PAYLOAD_LEN 
  #define PAYLOAD_LEN 10
  #endif
  #define SERIAL_PAUSE_TIME 10240UL

  typedef nx_struct test_payload{
    nx_uint8_t body[PAYLOAD_LEN];
    nx_uint32_t timestamp;
  } test_payload_t;

  task void getStatus(){
    printf("* Radio Status: %x\r\n", call Rf1aStatus.get());
    printf("* Channel: %u\r\n", channel);
    printf("* packetLength: %u\r\n", packetLength);
    printf("* repeat: %x\r\n", repeat);
    printf("* max_tx_short: %u\r\n", MAX_TX_SHORT);
    printf("* max_tx_long: %u\r\n", MAX_TX_LONG);
    printf("\r\n");
  }

  task void usage(){
    printf("USAGE\r\n");
    printf("-----\r\n");
    printf(" q: reset\r\n");
    printf(" r: receive packet\r\n");
    printf(" R: receive packet, no fwd\r\n");
    printf(" C: (check) receive with 1 second timeout\r\n");
    printf(" t: transmit packet\r\n");
    printf(" T: transmit packet, no retx\r\n");
    printf(" x: continuously repeat next requested action.\r\n");
    printf(" c: switch to next channel\r\n");
    printf(" l: toggle between 1-byte payload or max-len payload\r\n");
    printf(" s: sleep\r\n");
    printf(" k: kill serial (for 10 seconds)\r\n");
    printf(" S: toggle start/stop\r\n");
    printf("\r\n");
    post getStatus();
  }

  task void killSerial(){
    call SerialControl.stop();
    call Timer.startOneShot(SERIAL_PAUSE_TIME);
  }

  event void Boot.booted(){
//    channel = (TOS_NODE_ID)*(32);
    channel = 0;
    call SerialControl.start();
    printf("Booted\r\n");
    printf("\r\n");
    if(VERBOSE){
      post usage();
    }
    atomic{
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
//      //SMCLK to 1.1
//      P1MAP1 = PM_SMCLK;
      //GDO to 2.4 (synch)
      P2MAP4 = PM_RFGDO0;
      PMAPPWD = 0x00;

      P2DIR |= BIT4;
      P2SEL |= BIT4;
      
      //power on flash chip
      P2SEL &=~BIT1;
      P2OUT |=BIT1;

      //enable p1.2,3,4 for gpio
      P1DIR |= BIT1 | BIT2 | BIT3 | BIT4;
      P1SEL &= ~(BIT1 | BIT2 | BIT3 | BIT4);

      P1OUT &= ~(BIT1|BIT2|BIT3|BIT4);
    }
    post toggleStartStop();
  }

  void setChannel(){
    error_t error;
    error = call CXLink.setChannel(channel);
  }

  task void receivePacket(){ 
    error_t error; 
    setChannel();
    error = call CXLink.rx(0xFFFFFFFF, TRUE);
    if (error != SUCCESS){
      printf("!RX %x\r\n",
        error);
    }
  }

  task void receivePacketNoRetx(){ 
    setChannel();
    printf("RXn: %x\r\n",
      call CXLink.rx(0xFFFFFFFF, FALSE));
  }
  task void receivePacketShort(){
    setChannel();
    printf("RXs: %x\r\n",
      call CXLink.rx(6500000UL, TRUE));
  }

  void doSendPacket(bool retx){
    setChannel();
    if (txMsg){
      printf("~busy\r\n");
    }else{
      cx_link_header_t* header;
      test_payload_t* pl;
      error_t err;
      txMsg = call Pool.get();
      call Packet.clear(txMsg);
      header = call CXLinkPacket.getLinkHeader(txMsg);
//      pl = call Packet.getPayload(txMsg, sizeof(test_payload_t));
      pl = call Packet.getPayload(txMsg, 
        call Packet.maxPayloadLength());
//      printf("msg %p header %p pl %p md %p sn %u\r\n",
//        txMsg,
//        header,
//        pl,
//        call CXLinkPacket.getLinkMetadata(txMsg),
//        header->sn);
      header->ttl = 10;
      header->destination = AM_BROADCAST_ADDR;
      header->source = TOS_NODE_ID;
      call CXLinkPacket.setAllowRetx(txMsg, retx);   
//      if (packetLength >= sizeof(test_payload_t)){
//        call CXLinkPacket.setTSLoc(txMsg, &(pl->timestamp));
//      }
//      err = call Send.send(txMsg, sizeof(test_payload_t));
      err = call Send.send(txMsg, packetLength);
//      printf("Send: %x %x %u\r\n", retx, err, 
//        call Packet.payloadLength(txMsg));
      if (err != SUCCESS){
        printf("Send failed\r\n");
        call Pool.put(txMsg);
        txMsg = NULL;
      }
    }
  }

  task void sendPacketNoRetx(){ 
    doSendPacket(FALSE);
  }

  task void sendPacket(){ 
    doSendPacket(TRUE);
  }

  task void sleep(){
    error_t error = call CXLink.sleep();
    printf("Sleep: %x\r\n", error);
  }

  
  event void SplitControl.startDone(error_t error){ 
    if(VERBOSE){
    printf("start done: %x pool: %u\r\n", error, call Pool.size());
    }
    started = (error == SUCCESS);
    
    if (IS_SENDER){
      post sendPacket();
    } else {
      if (START_IN_RX){
        post receivePacket();
      }
    }
  }

  event void SplitControl.stopDone(error_t error){ 
    printf("stop done: %x pool: %u\r\n", error, call Pool.size());
    started = FALSE;
  }

  event void Send.sendDone(message_t* msg, error_t error){
    call Leds.led0Toggle();
    if (VERBOSE){
      printf("TX %u %u %x %u %u %x %x %x %x %lu\r\n", 
        (call CXLinkPacket.getLinkHeader(msg))->source,
        (call CXLinkPacket.getLinkHeader(msg))->sn,
        error,
        TEST_NUM,
        call Packet.payloadLength(msg),
        SELF_SFD_SYNCH,
        POWER_ADJUST,
        MIN_POWER,
        MAX_POWER,
        FRAMELEN_FAST_SHORT);
    }else{
      printf("TX %u %u\r\n", 
        (call CXLinkPacket.getLinkHeader(msg))->source,
        (call CXLinkPacket.getLinkHeader(msg))->sn);
    }
    if (msg == txMsg){
      call Pool.put(txMsg);
      txMsg = NULL;
    } else{
      printf("mystery packet: %p\r\n", msg);
    }
    if (repeat){
      if (packetLength < 32){
        call RetransmitTimer.startOneShot(2*TX_DELAY);
      }else{
        call RetransmitTimer.startOneShot(TX_DELAY);
      }
    }else if(repeatRX){
      post receivePacket();
    }
  }
  event void RetransmitTimer.fired(){
    post sendPacket();
  }

  task void handleRX(){
//    test_payload_t* pl = call Packet.getPayload(rxMsg,
//      sizeof(test_payload_t));
    if (VERBOSE){
      printf("RX %u %u %u %i %u %u %u %x %x %x %x %lu %u %u\r\n",
        (call CXLinkPacket.getLinkHeader(rxMsg))->source,
        (call CXLinkPacket.getLinkHeader(rxMsg))->sn,
        call CXLinkPacket.rxHopCount(rxMsg),
        call MessageRssi.rssi(rxMsg),
        call MessageLqi.lqi(rxMsg),
        TEST_NUM,
        call Packet.payloadLength(rxMsg),
        SELF_SFD_SYNCH,
        POWER_ADJUST,
        MIN_POWER,
        MAX_POWER, 
        FRAMELEN_FAST_SHORT,
        MAX_TX_SHORT,
        MAX_TX_LONG);
    }else{
      printf("RX %u %u %u %i %u\r\n",
        (call CXLinkPacket.getLinkHeader(rxMsg))->source,
        (call CXLinkPacket.getLinkHeader(rxMsg))->sn,
        call CXLinkPacket.rxHopCount(rxMsg),
        call MessageRssi.rssi(rxMsg),
        call MessageLqi.lqi(rxMsg));
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
        printf("pool empty\r\n");
        return msg;
      }
    }else{
      printf("Busy RX\r\n");
      return msg;
    }
  }

  event void CXLink.rxDone(){
    if ((txMsg == NULL) && (repeat || repeatRX) ){
      post receivePacket();
    }
  }

  task void toggleStartStop(){
    if (started){
      call SplitControl.stop();
    }else {
      call SplitControl.start();
    }
  }


  event void Timer.fired(){
    call SerialControl.start();
  }

  task void nextChannel(){
    do{
      channel += 32;
    } while (channel == 0);
    printf("Next channel: %u\r\n", channel);
  }

  task void togglePacketLength(){
    packetLength = (packetLength + 4)%114;
    printf("Packet length %u\r\n", packetLength);
  }

  task void toggleRepeat(){
    repeat = !repeat;
    post getStatus();
  }

  async event void UartStream.receivedByte(uint8_t byte){ 
     switch(byte){
       case 'q':
         WDTCTL = 0;
         break;
       case 'r':
         post receivePacket();
         break;
       case 'R':
         post receivePacketNoRetx();
         break;
       case 'C':
         post receivePacketShort();
         break;
       case 't':
         post sendPacket();
         return;
       case 'T':
         post sendPacketNoRetx();
         break;
       case 's':
         post sleep();
         break;
       case 'S':
         post toggleStartStop();
         break;
       case 'c':
         post nextChannel();
         break;
       case 'l':
         post togglePacketLength();
         break;
       case 'x':
         post toggleRepeat();
         break;
       case '?':
         post usage();
         break;
       case 'k':
         post killSerial();
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
