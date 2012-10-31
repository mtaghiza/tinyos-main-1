#ifndef CTRL_MESSAGES_H
#define CTRL_MESSAGES_H

#define BACON_BARCODE_LEN 8 
#define TOAST_BARCODE_LEN 8 

typedef nx_struct test_msg{
  nx_uint8_t counter;
} test_msg_t;

enum{
  AM_TEST_MSG = 0xDC,
};

//---- Begin Bacon commands
//Read interrupt vector (for safe BSL programming)
typedef nx_struct read_iv_cmd_msg{
  nx_uint8_t dummy[0];
} read_iv_cmd_msg_t;

typedef nx_struct read_iv_response_msg{
  nx_uint16_t iv[16];
} read_iv_response_msg_t;

//Read MFR ID
typedef nx_struct read_mfr_id_cmd_msg{
  nx_uint8_t dummy[0];
} read_mfr_id_cmd_msg_t;

typedef nx_struct read_mfr_id_response_msg{
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
  nx_uint8_t barcodeId[TOAST_BARCODE_LEN];
} read_toast_barcode_id_response_msg_t;

//Write toast barcode ID
typedef nx_struct write_toast_barcode_id_cmd_msg{
  nx_uint8_t barcodeId[TOAST_BARCODE_LEN];
} write_toast_barcode_id_cmd_msg_t;

typedef nx_struct write_toast_barcode_id_response_msg{
  nx_uint8_t error;
} write_toast_barcode_id_response_msg_t;




#endif
