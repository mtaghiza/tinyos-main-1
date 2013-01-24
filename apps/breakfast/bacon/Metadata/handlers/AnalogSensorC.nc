configuration AnalogSensorC{
  uses interface Pool<message_t>;
  uses interface Get<uint8_t> as LastSlave;
} implementation{
  components AnalogSensorP;
  AnalogSensorP.LastSlave = LastSlave;
  components ActiveMessageC;
  AnalogSensorP.Pool = Pool;
  AnalogSensorP.Packet -> ActiveMessageC;
  AnalogSensorP.AMPacket -> ActiveMessageC;

  components I2CADCReaderMasterC;
  AnalogSensorP.I2CADCReaderMaster -> I2CADCReaderMasterC;
  
  components new AMReceiverC(AM_READ_ANALOG_SENSOR_CMD_MSG) 
    as ReadAnalogSensorCmdReceive;
  AnalogSensorP.ReadAnalogSensorCmdReceive -> ReadAnalogSensorCmdReceive;
  
  components new AMSenderC(AM_READ_ANALOG_SENSOR_RESPONSE_MSG)
    as ReadAnalogSensorResponseSend;
  AnalogSensorP.ReadAnalogSensorResponseSend -> ReadAnalogSensorResponseSend;
}
