#ifndef SETTINGS_STORAGE_H
#define SETTINGS_STORAGE_H

#define MAX_SETTING_LEN 28

//hack for mig: mig doesn't appear to be picking up typedefs
//correctly? have to re-write the entire typedef each time
//Ideally, I'd do
/**
 typedef nx_struct settings_storage_msg {
   nx_uint8_t key;
   nx_uint8_t len;
   nx_uint8_t val[MAX_SETTING_LEN];
 }settings_storage_msg_t;

 typedef set_settings_storage_msg settings_storage_msg_t;
 typedef get_settings_storage_cmd_msg settings_storage_msg_t;
 typedef get_settings_storage_response_msg settings_storage_msg_t;
 typedef clear_settings_storage_msg settings_storage_msg_t;
*/
// But this gives "error: tag set_settings_storage_msg not found" when
// I try to generate for the set_settings_storage_msg struct.

//At any rate, the macro below essentially pastes the body of the
//original struct, which should have the same effect.

#define MIG_HACK_TYPEDEF(ALIAS, BODY) typedef nx_struct ALIAS BODY ALIAS ## _t;

#define SSMBODY {\
  nx_uint8_t error;\
  nx_uint8_t key;\
  nx_uint8_t len;\
  nx_uint8_t val[MAX_SETTING_LEN];\
} 

MIG_HACK_TYPEDEF(settings_storage_msg, SSMBODY)
MIG_HACK_TYPEDEF(set_settings_storage_msg, SSMBODY)
MIG_HACK_TYPEDEF(get_settings_storage_cmd_msg, SSMBODY)
MIG_HACK_TYPEDEF(get_settings_storage_response_msg, SSMBODY)
MIG_HACK_TYPEDEF(clear_settings_storage_msg, SSMBODY)

enum {
  AM_SET_SETTINGS_STORAGE_MSG = 0xC0,
  AM_GET_SETTINGS_STORAGE_CMD_MSG = 0xC1,
  AM_GET_SETTINGS_STORAGE_RESPONSE_MSG = 0xC2,
  AM_CLEAR_SETTINGS_STORAGE_MSG = 0xC3,
};

#define RECORD_TYPE_SETTINGS 0x17
#define SETTINGS_CHUNK_SIZE 64
typedef struct settings_record {
  uint8_t recordType;
  uint16_t rebootCounter;
  uint32_t ts;
  uint8_t offset;
  uint8_t data[SETTINGS_CHUNK_SIZE];
} __attribute__((packed)) settings_record_t;

#endif
