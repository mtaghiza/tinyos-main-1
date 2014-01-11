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


 #include "printf.h"
 #include "decodeError.h"

module MetadataP{
  uses interface Boot;
  uses interface Packet;
  uses interface SplitControl;
  uses interface Pool<message_t>;

  uses interface Leds;
  
  //Receive
  uses interface Receive as ReadIvCmdReceive;
  uses interface Receive as ReadMfrIdCmdReceive;
  uses interface Receive as ReadAdcCCmdReceive;
  uses interface Receive as ResetBaconCmdReceive;
  //Send
  uses interface AMSend as ReadIvResponseSend;
  uses interface AMSend as ReadMfrIdResponseSend;
  uses interface AMSend as ReadAdcCResponseSend;
  uses interface AMSend as ResetBaconResponseSend;

  uses interface AMPacket;
    
} implementation {
  enum {
    S_BOOTING ,
    S_READY
  };

  uint8_t state = S_BOOTING;
  am_addr_t cmdSource;

  event void Boot.booted(){
    call Leds.led0On();
    printf("Booted.\n");
    printfflush();
    call SplitControl.start();

    atomic{
      //map SFD to 1.2
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      P1MAP2 = PM_RFGDO0;
      PMAPPWD = 0x00;
  
      //set as output/function
      P1SEL |= BIT2;
      P1DIR |= BIT2;
  
      //disable flash chip
      P2SEL &= ~BIT1;
      P2OUT |=  BIT1;
      
      //set up 1.3 for GPIO (used for identifying atomic sections)
      P1SEL &= ~BIT3;
      P1DIR |=  BIT3;
      P1OUT &= ~BIT3;
    }
    
  }
  
  task void respondResetBacon();

  event void SplitControl.startDone(error_t error){ 
    state = S_READY;
    post respondResetBacon();
  }


  event void SplitControl.stopDone(error_t error){}

//Begin completed implementations
  //Reset Bacon
  message_t* ResetBacon_response_msg = NULL;
  
  task void resetBacon(){
    WDTCTL = 0;
  }

  event message_t* ResetBaconCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    post resetBacon();
    return msg_;
  }

  task void respondResetBacon(){
    if (call Pool.size()){
      ResetBacon_response_msg = call Pool.get(); 
      {
        reset_bacon_response_msg_t* responsePl = (reset_bacon_response_msg_t*)(call Packet.getPayload(ResetBacon_response_msg, sizeof(reset_bacon_response_msg_t)));
        responsePl->error = SUCCESS;
        //don't know where the request came from, so broadcast this
        //one.
        call ResetBaconResponseSend.send(AM_BROADCAST_ADDR, ResetBacon_response_msg,
          sizeof(reset_bacon_response_msg_t));
      }
    }
  }

  event void ResetBaconResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(ResetBacon_response_msg);
    ResetBacon_response_msg = NULL;
    call Leds.led0Off();
  }
  
  //Read bacon IV
  message_t* ReadIv_cmd_msg = NULL;
  message_t* ReadIv_response_msg = NULL;
  task void respondReadIv();

  event message_t* ReadIvCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (ReadIv_cmd_msg != NULL){
      printf("RX: ReadIv");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        ReadIv_response_msg = call Pool.get();
        ReadIv_cmd_msg = msg_;
        cmdSource = call AMPacket.source(msg_);
        printfflush();
        post respondReadIv();
        return ret;
      }else{
        printf("RX: ReadIv");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondReadIv(){
//    read_iv_cmd_msg_t* commandPl = (read_iv_cmd_msg_t*)(call Packet.getPayload(ReadIv_cmd_msg, sizeof(read_iv_cmd_msg_t)));
    read_iv_response_msg_t* responsePl = (read_iv_response_msg_t*)(call Packet.getPayload(ReadIv_response_msg, sizeof(read_iv_response_msg_t)));
    memcpy(&(responsePl->iv), (void*)0xFFE0, 32);
    responsePl->error = SUCCESS;
    call ReadIvResponseSend.send(cmdSource, ReadIv_response_msg, sizeof(read_iv_response_msg_t));
  }

  event void ReadIvResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(ReadIv_response_msg);
    call Pool.put(ReadIv_cmd_msg);
    ReadIv_cmd_msg = NULL;
    ReadIv_response_msg = NULL;
  }


  //Read bacon Manufacture info
  message_t* ReadMfrId_cmd_msg = NULL;
  message_t* ReadMfrId_response_msg = NULL;
  task void respondReadMfrId();

  event message_t* ReadMfrIdCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (ReadMfrId_cmd_msg != NULL){
      printf("RX: ReadMfrId");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        ReadMfrId_response_msg = call Pool.get();
        ReadMfrId_cmd_msg = msg_;
        cmdSource = call AMPacket.source(msg_);
        post respondReadMfrId();
        return ret;
      }else{
        printf("RX: ReadMfrId");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondReadMfrId(){
//    read_mfr_id_cmd_msg_t* commandPl = (read_mfr_id_cmd_msg_t*)(call Packet.getPayload(ReadMfrId_cmd_msg, sizeof(read_mfr_id_cmd_msg_t)));
    read_mfr_id_response_msg_t* responsePl = (read_mfr_id_response_msg_t*)(call Packet.getPayload(ReadMfrId_response_msg, sizeof(read_mfr_id_response_msg_t)));
    memcpy(&(responsePl->mfrId), (void*)0x1A0A, 8);
    responsePl->error = SUCCESS;
    call ReadMfrIdResponseSend.send(cmdSource, ReadMfrId_response_msg, sizeof(read_mfr_id_response_msg_t));
  }

  event void ReadMfrIdResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(ReadMfrId_response_msg);
    call Pool.put(ReadMfrId_cmd_msg);
    ReadMfrId_cmd_msg = NULL;
    ReadMfrId_response_msg = NULL;
  }




  //Read bacon Manufacture info
  message_t* ReadAdcC_cmd_msg = NULL;
  message_t* ReadAdcC_response_msg = NULL;
  task void respondReadAdcC();

  event message_t* ReadAdcCCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (ReadAdcC_cmd_msg != NULL){
      printf("RX: ReadAdcC");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        ReadAdcC_response_msg = call Pool.get();
        ReadAdcC_cmd_msg = msg_;
        cmdSource = call AMPacket.source(msg_);
        post respondReadAdcC();
        return ret;
      }else{
        printf("RX: ReadAdcC");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondReadAdcC(){
//    read_mfr_id_cmd_msg_t* commandPl = (read_mfr_id_cmd_msg_t*)(call Packet.getPayload(ReadAdcC_cmd_msg, sizeof(read_mfr_id_cmd_msg_t)));
    read_adc_c_response_msg_t* responsePl = (read_adc_c_response_msg_t*)(call Packet.getPayload(ReadAdcC_response_msg, sizeof(read_adc_c_response_msg_t)));
    memcpy(&(responsePl->adc), (void*)0x1A16, 24);
    responsePl->error = SUCCESS;
    call ReadAdcCResponseSend.send(cmdSource, ReadAdcC_response_msg, sizeof(read_adc_c_response_msg_t));
  }

  event void ReadAdcCResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(ReadAdcC_response_msg);
    call Pool.put(ReadAdcC_cmd_msg);
    ReadAdcC_cmd_msg = NULL;
    ReadAdcC_response_msg = NULL;
  }

//End completed implementations

}
