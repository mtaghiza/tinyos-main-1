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
        printf("RX: Ping");
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
    post printSettings();
    err = call I2CADCReaderMaster.sample(call LastSlave.get(), i2c_msg);
    printf("sample analog (%u, %p): %x\n", 
      call LastSlave.get(), i2c_msg, err);
    printfflush();
  }

  task void sendResponse();

  event i2c_message_t* I2CADCReaderMaster.sampleDone(error_t error,
      uint16_t slaveAddr, i2c_message_t* cmdMsg, i2c_message_t*
      responseMsg, adc_response_t* response){

    read_analog_sensor_response_msg_t* responsePl = (read_analog_sensor_response_msg_t*)(call Packet.getPayload(read_analog_sensor_response_msg, sizeof(read_analog_sensor_response_msg_t)));
    printf("DONE\n");
    printfflush();
    if (response != NULL){
      responsePl->sample = response->samples[0];
    }
    post sendResponse();
    return responseMsg;
  }

  task void sendResponse(){
    error_t err = call ReadAnalogSensorResponseSend.send(cmdSource, 
      read_analog_sensor_response_msg, 
      sizeof(read_analog_sensor_response_msg_t));
    printf("Send response: %x\n", err);
    printfflush();
  }

  event void ReadAnalogSensorResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(read_analog_sensor_response_msg);
    call Pool.put(read_analog_sensor_cmd_msg);
    read_analog_sensor_cmd_msg = NULL;
    read_analog_sensor_response_msg = NULL;
  }
 
}
