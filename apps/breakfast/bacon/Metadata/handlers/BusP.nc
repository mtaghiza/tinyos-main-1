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

 #include "GlobalID.h"
module BusP{
  uses interface SplitControl as BusControl;
  uses interface I2CDiscoverer;
  uses interface Packet;
  uses interface Pool<message_t>;

  uses interface Receive as ScanBusCmdReceive;
  uses interface Receive as SetBusPowerCmdReceive;
  uses interface AMSend as ScanBusResponseSend;
  uses interface AMSend as SetBusPowerResponseSend;

  uses interface AMPacket;

  provides interface Get<uint8_t>;
} implementation {
  am_addr_t cmdSource;

  uint8_t slaveCount;
  uint8_t lastSlave = 0;
  error_t scanBus_err;
  error_t setBusPower_error;

  task void respondScanBus();
  task void respondSetBusPower();
  task void reportBusPowerError();

  command uint8_t Get.get(){
    return lastSlave;
  }

  event void BusControl.startDone(error_t error){
    setBusPower_error = error;
    post respondSetBusPower();
  }

  event void BusControl.stopDone(error_t error){
    setBusPower_error = error;
    lastSlave = 0;
    post respondSetBusPower();
  }

  event uint16_t I2CDiscoverer.getLocalAddr(){
    return TOS_NODE_ID & 0x7F;
  }

  event discoverer_register_union_t* I2CDiscoverer.discovered(discoverer_register_union_t* discovery){
    uint8_t i;
    slaveCount++;
    printf("#Assigned %x to ", discovery->val.localAddr);
    for ( i = 0 ; i < GLOBAL_ID_LEN; i++){
      printf("%x ", discovery->val.globalAddr[i]);
    }
    if (slaveCount == 1){
      lastSlave = discovery->val.localAddr;
    }else{
      lastSlave = 0;
    }
    printf("\n");
    printfflush();
    return discovery;
  }

  event void I2CDiscoverer.discoveryDone(error_t error){
    scanBus_err = error;
    post respondScanBus();
  }

  //Scan bus
  message_t* ScanBus_cmd_msg = NULL;
  message_t* ScanBus_response_msg = NULL;
  task void respondScanBus();
  task void startDiscovery();

  event message_t* ScanBusCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (ScanBus_cmd_msg != NULL){
      printf("RX: ScanBus");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        ScanBus_response_msg = call Pool.get();
        ScanBus_cmd_msg = msg_;
        cmdSource = call AMPacket.source(msg_);
        post startDiscovery();
        return ret;
      }else{
        printf("RX: ScanBus");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void startDiscovery(){
    slaveCount = 0;
    lastSlave = 0;
    call I2CDiscoverer.startDiscovery(TRUE, 0x40);
  }


  task void respondScanBus(){
//    scan_bus_cmd_msg_t* commandPl = (scan_bus_cmd_msg_t*)(call Packet.getPayload(ScanBus_cmd_msg, sizeof(scan_bus_cmd_msg_t)));
    scan_bus_response_msg_t* responsePl = (scan_bus_response_msg_t*)(call Packet.getPayload(ScanBus_response_msg, sizeof(scan_bus_response_msg_t)));
    responsePl->error = scanBus_err;
    responsePl->numFound = slaveCount;
    call ScanBusResponseSend.send(cmdSource, ScanBus_response_msg, sizeof(scan_bus_response_msg_t));
  }

  event void ScanBusResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(ScanBus_response_msg);
    call Pool.put(ScanBus_cmd_msg);
    ScanBus_cmd_msg = NULL;
    ScanBus_response_msg = NULL;
//     printf("Response sent\n");
//     printfflush();
  }


  message_t* SetBusPower_cmd_msg = NULL;
  message_t* SetBusPower_response_msg = NULL;

  task void reportBusPowerError(){
    set_bus_power_response_msg_t* responsePl = (set_bus_power_response_msg_t*)(call Packet.getPayload(SetBusPower_response_msg, sizeof(set_bus_power_response_msg_t)));
    responsePl->error = setBusPower_error;
    call SetBusPowerResponseSend.send(cmdSource, SetBusPower_response_msg, sizeof(set_bus_power_response_msg_t));
  }

  task void setPowerTask(){
    set_bus_power_cmd_msg_t* commandPl = (set_bus_power_cmd_msg_t*)(call Packet.getPayload(SetBusPower_cmd_msg, sizeof(set_bus_power_cmd_msg_t)));
    if (commandPl->powerOn){
      setBusPower_error = call BusControl.start();
    } else {
      setBusPower_error = call BusControl.stop();
    }
    if (setBusPower_error != SUCCESS){
      post reportBusPowerError();
    }
  }

  event message_t* SetBusPowerCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (SetBusPower_cmd_msg != NULL){
      printf("RX: SetBusPower");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        SetBusPower_response_msg = call Pool.get();
        SetBusPower_cmd_msg = msg_;
        cmdSource = call AMPacket.source(msg_);
        post setPowerTask();
        return ret;
      }else{
        printf("RX: SetBusPower");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondSetBusPower(){
//    set_bus_power_cmd_msg_t* commandPl = (set_bus_power_cmd_msg_t*)(call Packet.getPayload(SetBusPower_cmd_msg, sizeof(set_bus_power_cmd_msg_t)));
    set_bus_power_response_msg_t* responsePl = (set_bus_power_response_msg_t*)(call Packet.getPayload(SetBusPower_response_msg, sizeof(set_bus_power_response_msg_t)));
    responsePl->error = SUCCESS;
    call SetBusPowerResponseSend.send(cmdSource, SetBusPower_response_msg, sizeof(set_bus_power_response_msg_t));
  }

  event void SetBusPowerResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(SetBusPower_response_msg);
    call Pool.put(SetBusPower_cmd_msg);
    SetBusPower_cmd_msg = NULL;
    SetBusPower_response_msg = NULL;
  }
 

}
