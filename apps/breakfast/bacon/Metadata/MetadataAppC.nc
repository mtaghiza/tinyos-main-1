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

 #include "ctrl_messages.h"
configuration MetadataAppC{
} implementation {
  components MainC;
  components MetadataP;
  components UtilitiesC;
  components BusC;
  components ToastTLVC;
  components BaconTLVC;

  components BaconSensorC;

  components new TimerMilliC();

  components PrintfC;
  components SerialStartC;

  components WatchDogC;
  
  components MDActiveMessageC as ActiveMessageC;

  MetadataP.Boot -> MainC;

  MetadataP.Packet -> ActiveMessageC;
  MetadataP.AMPacket -> ActiveMessageC;
  MetadataP.SplitControl -> ActiveMessageC;

  components new PoolC(message_t, 8);
  MetadataP.Pool -> PoolC;
  UtilitiesC.Pool -> PoolC;
  BusC.Pool -> PoolC;
  ToastTLVC.Pool -> PoolC;
  BaconTLVC.Pool -> PoolC;

  ToastTLVC.LastSlave -> BusC.Get;

  components AnalogSensorC;
  AnalogSensorC.Pool -> PoolC;
  AnalogSensorC.LastSlave -> BusC.Get;

  components LedsC;
  MetadataP.Leds -> LedsC;


  //Receive
  components new MDAMReceiverC(AM_READ_IV_CMD_MSG) as ReadIvCmdReceive;
  MetadataP.ReadIvCmdReceive -> ReadIvCmdReceive;
  components new MDAMReceiverC(AM_READ_MFR_ID_CMD_MSG) as ReadMfrIdCmdReceive;
  MetadataP.ReadMfrIdCmdReceive -> ReadMfrIdCmdReceive;
  components new MDAMReceiverC(AM_READ_ADC_C_CMD_MSG) as ReadAdcCCmdReceive;
  MetadataP.ReadAdcCCmdReceive -> ReadAdcCCmdReceive;
  components new MDAMReceiverC(AM_RESET_BACON_CMD_MSG) as ResetBaconCmdReceive;
  MetadataP.ResetBaconCmdReceive -> ResetBaconCmdReceive;
  //Send
  components new MDAMSenderC(AM_READ_IV_RESPONSE_MSG) as ReadIvResponseSend;
  MetadataP.ReadIvResponseSend -> ReadIvResponseSend;
  components new MDAMSenderC(AM_READ_MFR_ID_RESPONSE_MSG) as ReadMfrIdResponseSend;
  MetadataP.ReadMfrIdResponseSend -> ReadMfrIdResponseSend;
  components new MDAMSenderC(AM_READ_ADC_C_RESPONSE_MSG) as ReadAdcCResponseSend;
  MetadataP.ReadAdcCResponseSend -> ReadAdcCResponseSend;
  components new MDAMSenderC(AM_RESET_BACON_RESPONSE_MSG) as ResetBaconResponseSend;
  MetadataP.ResetBaconResponseSend -> ResetBaconResponseSend;
  
}
