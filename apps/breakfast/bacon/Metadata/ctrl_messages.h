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

#ifndef CTRL_MESSAGES_H
#define CTRL_MESSAGES_H

#define BACON_BARCODE_LEN 8
#define TOAST_BARCODE_LEN 8

#include "I2CADCReader.h"

//---- Begin Bacon commands
//Read interrupt vector (for safe BSL programming)
typedef nx_struct read_iv_cmd_msg{
  nx_uint8_t dummy[0];
} read_iv_cmd_msg_t;

typedef nx_struct read_iv_response_msg{
  nx_uint8_t error;
  nx_uint16_t iv[16];
} read_iv_response_msg_t;

//Read MFR ID
typedef nx_struct read_mfr_id_cmd_msg{
  nx_uint8_t dummy[0];
} read_mfr_id_cmd_msg_t;

typedef nx_struct read_mfr_id_response_msg{
  nx_uint8_t error;
  nx_uint8_t mfrId[8];
} read_mfr_id_response_msg_t;

//Read ADC Constants
typedef nx_struct read_adc_c_cmd_msg{
  nx_uint8_t dummy[0];
} read_adc_c_cmd_msg_t;

typedef nx_struct read_adc_c_response_msg{
  nx_uint8_t error;
  nx_uint8_t adc[24];
} read_adc_c_response_msg_t;

//Read bacon barcode ID
typedef nx_struct read_bacon_barcode_id_cmd_msg{
  nx_uint8_t tag;
} read_bacon_barcode_id_cmd_msg_t;

typedef nx_struct read_bacon_barcode_id_response_msg{
  nx_uint8_t error;
  nx_uint8_t tag;
  nx_uint8_t len;
  nx_uint8_t barcodeId[BACON_BARCODE_LEN];
} read_bacon_barcode_id_response_msg_t;

//Write bacon barcode ID
typedef nx_struct write_bacon_barcode_id_cmd_msg{
  nx_uint8_t tag;
  nx_uint8_t len;
  nx_uint8_t barcodeId[BACON_BARCODE_LEN];
} write_bacon_barcode_id_cmd_msg_t;

typedef nx_struct write_bacon_barcode_id_response_msg{
  nx_uint8_t error;
} write_bacon_barcode_id_response_msg_t;

//---Begin Toast commands
//Read toast barcode ID
typedef nx_struct read_toast_barcode_id_cmd_msg{
  nx_uint8_t tag;
} read_toast_barcode_id_cmd_msg_t;

typedef nx_struct read_toast_barcode_id_response_msg{
  nx_uint8_t error;
  nx_uint8_t tag;
  nx_uint8_t len;
  nx_uint8_t barcodeId[TOAST_BARCODE_LEN];
} read_toast_barcode_id_response_msg_t;

typedef nx_struct write_bacon_version_cmd_msg{
  nx_uint8_t tag;
  nx_uint8_t len;
  nx_uint16_t version;
}write_bacon_version_cmd_msg_t;

typedef nx_struct write_bacon_version_response_msg{
  nx_uint8_t error;
} write_bacon_version_response_msg_t;

typedef nx_struct read_bacon_version_cmd_msg{
  nx_uint8_t tag;
} read_bacon_version_cmd_msg_t;

typedef nx_struct read_bacon_version_response_msg{
  nx_uint8_t error;
  nx_uint8_t tag;
  nx_uint8_t len;
  nx_uint16_t version;
} read_bacon_version_response_msg_t;

//Write toast barcode ID
typedef nx_struct write_toast_barcode_id_cmd_msg{
  nx_uint8_t tag;
  nx_uint8_t len;
  nx_uint8_t barcodeId[TOAST_BARCODE_LEN];
} write_toast_barcode_id_cmd_msg_t;

typedef nx_struct write_toast_barcode_id_response_msg{
  nx_uint8_t error;
} write_toast_barcode_id_response_msg_t;

//--- Analog sensor transactions
typedef nx_struct sensor_assignment{
  nx_uint8_t sensorType;
  nx_uint16_t sensorId;
} sensor_assignment_t;

typedef nx_struct read_toast_assignments_cmd_msg{
  nx_uint8_t tag;
  nx_uint8_t dummy[0];
}read_toast_assignments_cmd_msg_t;

typedef nx_struct read_toast_assignments_response_msg{
  nx_uint8_t error;
  nx_uint8_t tag;
  nx_uint8_t len;
  sensor_assignment_t assignments[8];
}read_toast_assignments_response_msg_t;

typedef nx_struct write_toast_assignments_cmd_msg{
  nx_uint8_t tag;
  nx_uint8_t len;
  sensor_assignment_t assignments[8];
}write_toast_assignments_cmd_msg_t;

typedef nx_struct write_toast_assignments_response_msg{
  nx_uint8_t error;
} write_toast_assignments_response_msg_t;

typedef nx_struct write_toast_version_cmd_msg{
  nx_uint8_t tag;
  nx_uint8_t len;
  nx_uint16_t version;
}write_toast_version_cmd_msg_t;

typedef nx_struct write_toast_version_response_msg{
  nx_uint8_t error;
} write_toast_version_response_msg_t;

typedef nx_struct read_toast_version_cmd_msg{
  nx_uint8_t tag;
} read_toast_version_cmd_msg_t;

typedef nx_struct read_toast_version_response_msg{
  nx_uint8_t error;
  nx_uint8_t tag;
  nx_uint8_t len;
  nx_uint16_t version;
} read_toast_version_response_msg_t;

typedef nx_struct read_analog_sensor_cmd_msg{
  nx_uint32_t delayMS;
  nx_uint16_t samplePeriod;
  nx_uint8_t inch;
  nx_uint8_t sref;
  nx_uint8_t ref2_5v;
  nx_uint8_t adc12ssel;
  nx_uint8_t adc12div;
  nx_uint8_t sht;
  nx_uint8_t sampcon_ssel;
  nx_uint8_t sampcon_id;
} read_analog_sensor_cmd_msg_t;

typedef nx_struct read_analog_sensor_response_msg{
  adc_sample_t sample;
} read_analog_sensor_response_msg_t;

typedef nx_struct read_bacon_sensor_cmd_msg {
  nx_uint8_t dummy[0];
} read_bacon_sensor_cmd_msg_t;

typedef nx_struct read_bacon_sensor_response_msg {
  nx_uint8_t error;
  nx_uint16_t light;
  nx_uint16_t thermistor;
  nx_uint16_t battery;
} read_bacon_sensor_response_msg_t;

//---Utilities
typedef nx_struct scan_bus_cmd_msg{
  nx_uint8_t dummy[0];
} scan_bus_cmd_msg_t;

typedef nx_struct scan_bus_response_msg{
  nx_uint8_t error;
  nx_uint8_t numFound;
} scan_bus_response_msg_t;

typedef nx_struct ping_cmd_msg{
  nx_uint8_t dummy[0];
} ping_cmd_msg_t;

typedef nx_struct ping_response_msg{
  nx_uint8_t error;
} ping_response_msg_t;

typedef nx_struct reset_bacon_cmd_msg{
  nx_uint8_t dummy[0];
} reset_bacon_cmd_msg_t;

typedef nx_struct reset_bacon_response_msg{
  nx_uint8_t error;
} reset_bacon_response_msg_t;

typedef nx_struct set_bus_power_cmd_msg{
  nx_uint8_t powerOn;
} set_bus_power_cmd_msg_t;

typedef nx_struct set_bus_power_response_msg{
  nx_uint8_t error;
} set_bus_power_response_msg_t;

//--- Generic low-level commands
//Read/write entire TLV storage space: mote will handle checksum.
typedef nx_struct read_bacon_tlv_cmd_msg{
  nx_uint8_t dummy[0];
} read_bacon_tlv_cmd_msg_t;

typedef nx_struct read_bacon_tlv_response_msg{
  nx_uint8_t error;
  nx_uint8_t tlvs[128];
} read_bacon_tlv_response_msg_t;

typedef nx_struct read_toast_tlv_cmd_msg{
  nx_uint8_t dummy[0];
} read_toast_tlv_cmd_msg_t;

typedef nx_struct read_toast_tlv_response_msg{
  nx_uint8_t error;
  nx_uint8_t tlvs[64];
} read_toast_tlv_response_msg_t;

typedef nx_struct write_bacon_tlv_cmd_msg{
  nx_uint8_t tlvs[128];
} write_bacon_tlv_cmd_msg_t;

typedef nx_struct write_bacon_tlv_response_msg{
  nx_uint8_t error;
} write_bacon_tlv_response_msg_t;

typedef nx_struct write_toast_tlv_cmd_msg{
  nx_uint8_t tlvs[64];
} write_toast_tlv_cmd_msg_t;

typedef nx_struct write_toast_tlv_response_msg{
  nx_uint8_t error;
} write_toast_tlv_response_msg_t;

//Delete single TLV entry
typedef nx_struct delete_bacon_tlv_entry_cmd_msg{
  nx_uint8_t tag;
} delete_bacon_tlv_entry_cmd_msg_t;

typedef nx_struct delete_bacon_tlv_entry_response_msg{
  nx_uint8_t error;
} delete_bacon_tlv_entry_response_msg_t;

typedef nx_struct delete_toast_tlv_entry_cmd_msg{
  nx_uint8_t tag;
} delete_toast_tlv_entry_cmd_msg_t;

typedef nx_struct delete_toast_tlv_entry_response_msg{
  nx_uint8_t error;
} delete_toast_tlv_entry_response_msg_t;

//Add single TLV entry
typedef nx_struct add_bacon_tlv_entry_cmd_msg{
  nx_uint8_t tag;
  nx_uint8_t len;
  nx_uint8_t data[128];
} add_bacon_tlv_entry_cmd_msg_t;

typedef nx_struct add_bacon_tlv_entry_response_msg{
  nx_uint8_t error;
} add_bacon_tlv_entry_response_msg_t;

typedef nx_struct add_toast_tlv_entry_cmd_msg{
  nx_uint8_t tag;
  nx_uint8_t len;
  nx_uint8_t data[64];
} add_toast_tlv_entry_cmd_msg_t;

typedef nx_struct add_toast_tlv_entry_response_msg{
  nx_uint8_t error;
} add_toast_tlv_entry_response_msg_t;

//Read a single TLV Entry

typedef nx_struct read_bacon_tlv_entry_cmd_msg{
  nx_uint8_t tag;
} read_bacon_tlv_entry_cmd_msg_t;

typedef nx_struct read_bacon_tlv_entry_response_msg{
  nx_uint8_t error;
  nx_uint8_t tag;
  nx_uint8_t len;
  nx_uint8_t data[128];
} read_bacon_tlv_entry_response_msg_t;

typedef nx_struct read_toast_tlv_entry_cmd_msg{
  nx_uint8_t tag;
} read_toast_tlv_entry_cmd_msg_t;
//these would ideally use the tlv_entry_t type, but that's not an nx
//type
typedef nx_struct read_toast_tlv_entry_response_msg{
  nx_uint8_t error;
  nx_uint8_t tag;
  nx_uint8_t len;
  nx_uint8_t data[64];
} read_toast_tlv_entry_response_msg_t;


enum{
  AM_READ_IV_CMD_MSG = 0x80,
  AM_READ_IV_RESPONSE_MSG = 0x81,
  AM_READ_MFR_ID_CMD_MSG = 0x82,
  AM_READ_MFR_ID_RESPONSE_MSG = 0x83,
  AM_READ_ADC_C_CMD_MSG = 0xB2,
  AM_READ_ADC_C_RESPONSE_MSG = 0xB3,
  //
  //Bacon Commands
  //
  //generic read TLV
  AM_READ_BACON_BARCODE_ID_CMD_MSG = 0xAA,
  AM_READ_BACON_BARCODE_ID_RESPONSE_MSG = 0x85,
  //generic add TLV
  AM_WRITE_BACON_BARCODE_ID_CMD_MSG = 0xA4,
  AM_WRITE_BACON_BARCODE_ID_RESPONSE_MSG = 0x87,
  //uses generic add TLV
  AM_WRITE_BACON_VERSION_CMD_MSG = 0xA4,
  AM_WRITE_BACON_VERSION_RESPONSE_MSG = 0xAE,
  //uses generic read tlv
  AM_READ_BACON_VERSION_CMD_MSG = 0xAA,
  AM_READ_BACON_VERSION_RESPONSE_MSG = 0xAF,

  //
  //TOAST COMMANDS
  //
  //uses generic read tlv
  AM_READ_TOAST_BARCODE_ID_CMD_MSG = 0xA8,
  AM_READ_TOAST_BARCODE_ID_RESPONSE_MSG = 0x89,
  //uses generic add TLV
  AM_WRITE_TOAST_BARCODE_ID_CMD_MSG = 0xA6,
  AM_WRITE_TOAST_BARCODE_ID_RESPONSE_MSG = 0x8B,
  //uses generic read tlv
  AM_READ_TOAST_ASSIGNMENTS_CMD_MSG = 0xA8,
  AM_READ_TOAST_ASSIGNMENTS_RESPONSE_MSG = 0x8D,
  //uses generic add TLV
  AM_WRITE_TOAST_ASSIGNMENTS_CMD_MSG = 0xA6,
  AM_WRITE_TOAST_ASSIGNMENTS_RESPONSE_MSG = 0x8F,
  //uses generic add TLV
  AM_WRITE_TOAST_VERSION_CMD_MSG = 0xA6,
  AM_WRITE_TOAST_VERSION_RESPONSE_MSG = 0xAC,
  //uses generic read tlv
  AM_READ_TOAST_VERSION_CMD_MSG = 0xA8,
  AM_READ_TOAST_VERSION_RESPONSE_MSG = 0xAD,

  //
  //ANALOG SENSOR COMMANDS
  //
  AM_READ_ANALOG_SENSOR_CMD_MSG = 0xB0,
  AM_READ_ANALOG_SENSOR_RESPONSE_MSG = 0xB1,

  AM_READ_BACON_SENSOR_CMD_MSG = 0xB2,
  AM_READ_BACON_SENSOR_RESPONSE_MSG = 0xB3,


  //
  //Utilities
  //
  AM_SCAN_BUS_CMD_MSG = 0x90,
  AM_SCAN_BUS_RESPONSE_MSG = 0x91,
  AM_PING_CMD_MSG = 0x92,
  AM_PING_RESPONSE_MSG = 0x93,
  AM_RESET_BACON_CMD_MSG = 0x94,
  AM_RESET_BACON_RESPONSE_MSG = 0x95,
  AM_SET_BUS_POWER_CMD_MSG = 0x96,
  AM_SET_BUS_POWER_RESPONSE_MSG = 0x97,
  //
  //Generics
  //
  AM_READ_BACON_TLV_CMD_MSG = 0x98,
  AM_READ_BACON_TLV_RESPONSE_MSG = 0x99,
  AM_READ_TOAST_TLV_CMD_MSG = 0x9A,
  AM_READ_TOAST_TLV_RESPONSE_MSG = 0x9B,
  AM_WRITE_BACON_TLV_CMD_MSG = 0x9C,
  AM_WRITE_BACON_TLV_RESPONSE_MSG = 0x9D,
  AM_WRITE_TOAST_TLV_CMD_MSG = 0x9E,
  AM_WRITE_TOAST_TLV_RESPONSE_MSG = 0x9F,
  AM_DELETE_BACON_TLV_ENTRY_CMD_MSG = 0xA0,
  AM_DELETE_BACON_TLV_ENTRY_RESPONSE_MSG = 0xA1,
  AM_DELETE_TOAST_TLV_ENTRY_CMD_MSG = 0xA2,
  AM_DELETE_TOAST_TLV_ENTRY_RESPONSE_MSG = 0xA3,
  AM_ADD_BACON_TLV_ENTRY_CMD_MSG = 0xA4,
  AM_ADD_BACON_TLV_ENTRY_RESPONSE_MSG = 0xA5,
  AM_ADD_TOAST_TLV_ENTRY_CMD_MSG = 0xA6,
  AM_ADD_TOAST_TLV_ENTRY_RESPONSE_MSG = 0xA7,
  AM_READ_TOAST_TLV_ENTRY_CMD_MSG = 0xA8,
  AM_READ_TOAST_TLV_ENTRY_RESPONSE_MSG = 0xA9,
  AM_READ_BACON_TLV_ENTRY_CMD_MSG = 0xAA,
  AM_READ_BACON_TLV_ENTRY_RESPONSE_MSG = 0xAB,
};

#endif
