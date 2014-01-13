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
module BaconSensorP{
  uses interface Receive as ReadBaconSensorCmdReceive;
  uses interface AMSend as ReadBaconSensorResponseSend;
  uses interface AMPacket;
  uses interface Packet;
  uses interface Pool<message_t>;
} implementation {
  message_t* responseMsg = NULL;
  am_id_t currentCommandType; 
  am_addr_t cmdSource;
//Begin Auto-generated message stubs (see genStubs.sh)
  task void respondReadBaconSensor();

  task void readBaconSensor(){
    //TODO: actually read the sensors.
    post respondReadBaconSensor();
  }

  event message_t* ReadBaconSensorCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (responseMsg == NULL){
      responseMsg = call Pool.get();
      post readBaconSensor();
    }
    return msg_;
  }

  task void respondReadBaconSensor(){
    read_bacon_sensor_response_msg_t* responsePl = (read_bacon_sensor_response_msg_t*)(call Packet.getPayload(responseMsg, sizeof(read_bacon_sensor_response_msg_t)));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call ReadBaconSensorResponseSend.send(0, responseMsg, sizeof(read_bacon_sensor_response_msg_t));
  }

  event void ReadBaconSensorResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(responseMsg);
    responseMsg = NULL;
    printf("Response sent\n");
    printfflush();
  }


//End auto-generated message stubs


}
