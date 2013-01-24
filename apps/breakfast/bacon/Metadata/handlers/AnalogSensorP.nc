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
        printf("RX: Ping");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondReadAnalogSensor(){
    read_analog_sensor_cmd_msg_t* commandPl =
      (read_analog_sensor_cmd_msg_t*)(call Packet.getPayload(read_analog_sensor_cmd_msg,
        sizeof(read_analog_sensor_cmd_msg_t)));
    adc_reader_pkt_t* cmd = call I2CADCReaderMaster.getSettings(i2c_msg); 
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
    //mark end of sequence
    cmd->cfg[1].config.inch = INPUT_CHANNEL_NONE;
    call I2CADCReaderMaster.sample(call LastSlave.get(), i2c_msg);
  }

  task void sendResponse();

  event i2c_message_t* I2CADCReaderMaster.sampleDone(error_t error,
      uint16_t slaveAddr, i2c_message_t* cmdMsg, i2c_message_t*
      responseMsg, adc_response_t* response){

    read_analog_sensor_response_msg_t* responsePl = (read_analog_sensor_response_msg_t*)(call Packet.getPayload(read_analog_sensor_response_msg, sizeof(read_analog_sensor_response_msg_t)));
    if (response != NULL){
      responsePl->sample = response->samples[0];
    }
    post sendResponse();
    return responseMsg;
  }

  task void sendResponse(){
    call ReadAnalogSensorResponseSend.send(cmdSource, 
      read_analog_sensor_response_msg, 
      sizeof(read_analog_sensor_response_msg_t));
  }

  event void ReadAnalogSensorResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(read_analog_sensor_response_msg);
    call Pool.put(read_analog_sensor_cmd_msg);
    read_analog_sensor_cmd_msg = NULL;
    read_analog_sensor_response_msg = NULL;
  }
 
}
