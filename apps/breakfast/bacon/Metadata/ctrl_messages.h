#ifndef CTRL_MESSAGES_H
#define CTRL_MESSAGES_H

#define BACON_BARCODE_LEN 8 
#define TOAST_BARCODE_LEN 8 
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

//Read bacon barcode ID
typedef nx_struct read_bacon_barcode_id_cmd_msg{
  nx_uint8_t dummy[0];
} read_bacon_barcode_id_cmd_msg_t;

typedef nx_struct read_bacon_barcode_id_response_msg{
  nx_uint8_t error;
  nx_uint8_t barcodeId[BACON_BARCODE_LEN];
} read_bacon_barcode_id_response_msg_t;

//Write bacon barcode ID
typedef nx_struct write_bacon_barcode_id_cmd_msg{
  nx_uint8_t barcodeId[BACON_BARCODE_LEN];
} write_bacon_barcode_id_cmd_msg_t;

typedef nx_struct write_bacon_barcode_id_response_msg{
  nx_uint8_t error;
} write_bacon_barcode_id_response_msg_t;

//---Begin Toast commands
//Read toast barcode ID
typedef nx_struct read_toast_barcode_id_cmd_msg{
  nx_uint8_t dummy[0];
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
  nx_uint8_t dummy[0];
} read_bacon_version_cmd_msg_t;

typedef nx_struct read_bacon_version_response_msg{
  nx_uint8_t error;
  nx_uint8_t tag;
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
  nx_uint8_t dummy[0];
} read_toast_version_cmd_msg_t;

typedef nx_struct read_toast_version_response_msg{
  nx_uint8_t error;
  nx_uint8_t tag;
  nx_uint16_t version;
} read_toast_version_response_msg_t;

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
  nx_uint8_t tlvs[64];
} read_bacon_tlv_response_msg_t;

typedef nx_struct read_toast_tlv_cmd_msg{
  nx_uint8_t dummy[0];
} read_toast_tlv_cmd_msg_t;

typedef nx_struct read_toast_tlv_response_msg{
  nx_uint8_t error;
  nx_uint8_t tlvs[64];
} read_toast_tlv_response_msg_t;

typedef nx_struct write_bacon_tlv_cmd_msg{
  nx_uint8_t tlvs[64];
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
  nx_uint8_t data[64];
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
  nx_uint8_t data[64];
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
  AM_READ_TOAST_VERSION_CMD_MSG = 0xA6,
  AM_READ_TOAST_VERSION_RESPONSE_MSG = 0xAD,

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
