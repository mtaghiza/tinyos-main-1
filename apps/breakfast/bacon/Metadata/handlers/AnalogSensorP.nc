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

module AnalogSensorP {
  uses interface Packet;
  uses interface AMPacket;
  uses interface Pool<message_t>;
  uses interface Get<uint8_t> as LastSlave;

  uses interface I2CADCReaderMaster;
  
  uses interface Receive as ReadAnalogSensorCmdReceive;
  uses interface AMSend as ReadAnalogSensorResponseSend;
} implementation {
  am_addr_t cmdSource;
  
  i2c_message_t i2c_msg_internal;
  i2c_message_t* i2c_msg = &i2c_msg_internal;
  
  message_t* read_analog_sensor_cmd_msg = NULL;
  message_t* read_analog_sensor_response_msg = NULL;
  task void respondReadAnalogSensor();

  const char* sref_str[7] = {
   "AVcc_AVss",
   "VREFplus_AVss",
   "VeREFplus_AVss",
   "INVAL_3",
   "AVcc_VREFnegterm",
   "VREFplus_VREFnegterm",
   "VeREFplus_VREFnegterm"
  };

  const char* ref2_5v_str[2] = {
    "1_5",
    "2_5",
  };

  task void printSettings(){
    uint8_t i;
    adc_reader_pkt_t* cmd = call I2CADCReaderMaster.getSettings(i2c_msg);
    printf("Settings (inch delayMS sref_enum ref2_5_enum)\n\r");
    for (i=0; i < ADC_NUM_CHANNELS; i++){
      printf("  [%d] : %x ", i, cmd->cfg[i].config.inch);
      if (cmd->cfg[i].config.inch == INPUT_CHANNEL_NONE){
        printf("(None)\n\r");
        break;
      } else {
        printf("%lu\t%s\t%s\n\r", cmd->cfg[i].delayMS,
          sref_str[cmd->cfg[i].config.sref], 
          ref2_5v_str[cmd->cfg[i].config.ref2_5v]);
      }
    }
  }


  event message_t* ReadAnalogSensorCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (read_analog_sensor_cmd_msg != NULL){
      printf("RX: ReadAnalogSensor");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        read_analog_sensor_response_msg = call Pool.get();
        read_analog_sensor_cmd_msg = msg_;
        cmdSource = call AMPacket.source(msg_);
        post respondReadAnalogSensor();
        return ret;
      }else{
        printf("RX: ReadAnalogSensor");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondReadAnalogSensor(){
    error_t err;
    read_analog_sensor_cmd_msg_t* commandPl =
      (read_analog_sensor_cmd_msg_t*)(call Packet.getPayload(read_analog_sensor_cmd_msg,
        sizeof(read_analog_sensor_cmd_msg_t)));
    adc_reader_pkt_t* cmd = call I2CADCReaderMaster.getSettings(i2c_msg); 
    cmd -> cfg[1].config.inch = INPUT_CHANNEL_NONE;
//     printf("cmd: %u each %u (x%u)\n", 
//       sizeof(adc_reader_pkt_t), 
//       sizeof(adc_reader_config_t),
//       ADC_NUM_CHANNELS);
//    memset(cmd, 0, sizeof(adc_reader_pkt_t));
//    {
//      uint8_t i;
//      for (i=0; i < ADC_NUM_CHANNELS; i++){
//        cmd->cfg[i].config.inch = INPUT_CHANNEL_NONE;
//      }
//    }
    cmd->cfg[0].delayMS = commandPl->delayMS;
    cmd->cfg[0].samplePeriod = commandPl->samplePeriod;
    cmd->cfg[0].config.inch = commandPl->inch;
    cmd->cfg[0].config.sref = commandPl->sref;
    cmd->cfg[0].config.ref2_5v = commandPl->ref2_5v;
    cmd->cfg[0].config.adc12ssel = commandPl->adc12ssel;
    cmd->cfg[0].config.adc12div = commandPl->adc12div;
    cmd->cfg[0].config.sht = commandPl->sht;
    cmd->cfg[0].config.sampcon_ssel = commandPl->sampcon_ssel;
    cmd->cfg[0].config.sampcon_id = commandPl->sampcon_id; 

//    post printSettings();
    err = call I2CADCReaderMaster.sample(call LastSlave.get(), i2c_msg);
//    printf("sample analog (%u, %p, %p): %x\n", 
//      call LastSlave.get(), i2c_msg, cmd, err);
//    printfflush();
  }

  task void sendResponse();
  
  i2c_message_t* cmdMsg;
  i2c_message_t* responseMsg;
  uint8_t i2c_index;

  task void printRead(){
    //odd.. it seems like the LA is only reporting the body
    if (i2c_index < responseMsg->body.header.len + sizeof(i2c_message_header_t)){
      printf("[%u] %02X\n", i2c_index, responseMsg->body.buf[i2c_index]);
//      printfflush();
      i2c_index++;
      post printRead();
    }else{
      printfflush();
    }
    
  }

  task void printWritten(){
    if (i2c_index < cmdMsg->body.header.len + sizeof(i2c_message_header_t)){
      printf("[%u] %02X\n", i2c_index, cmdMsg->buf[i2c_index]);
 //     printfflush();
      i2c_index++;
      post printWritten();
    }else{
      i2c_index = 0;
      printf("READ\n");
      post printRead();
    }
  }

  task void printExchange(){
    i2c_index = 0;
    printf("WROTE\n");
    post printWritten();

  }

  event i2c_message_t* I2CADCReaderMaster.sampleDone(error_t error,
      uint16_t slaveAddr, i2c_message_t* cmdMsg_, i2c_message_t*
      responseMsg_, adc_response_t* response){
   
    read_analog_sensor_response_msg_t* responsePl = (read_analog_sensor_response_msg_t*)(call Packet.getPayload(read_analog_sensor_response_msg, sizeof(read_analog_sensor_response_msg_t)));
    responseMsg = responseMsg_;
    cmdMsg = cmdMsg_;
    if (response != NULL){
      responsePl->sample = response->samples[0];
    }
//    printf("sampleDone: error: %x i2c cmd %p i2c response %p AM c %p AM r %p st %lu st' %lu\n", 
//      error,
//      cmdMsg, 
//      responseMsg,
//      read_analog_sensor_cmd_msg,
//      read_analog_sensor_response_msg,
//      response->samples[0].sampleTime,
//      responsePl->sample.sampleTime);
//     printf("sd: %x inch %u st %lu\n", error,
//       response->samples[0].inputChannel,
//       response->samples[0].sampleTime);
//     printfflush();
    post sendResponse();
    return responseMsg;
  }

  task void sendResponse(){
    error_t err;
//    printf("Send: %u %p %u\n", cmdSource, 
//      read_analog_sensor_response_msg, 
//      sizeof(read_analog_sensor_response_msg_t));
    err = call ReadAnalogSensorResponseSend.send(cmdSource, 
      read_analog_sensor_response_msg, 
      sizeof(read_analog_sensor_response_msg_t));
//    printf("Send err: %x\n", err);
  }

  event void ReadAnalogSensorResponseSend.sendDone(message_t* msg, 
      error_t error){
//    printf("Send done: response %p cmd %p\n",
//      read_analog_sensor_response_msg,
//      read_analog_sensor_cmd_msg);
    call Pool.put(read_analog_sensor_response_msg);
    call Pool.put(read_analog_sensor_cmd_msg);
    read_analog_sensor_cmd_msg = NULL;
    read_analog_sensor_response_msg = NULL;
//    post printExchange();
  }
 
}
