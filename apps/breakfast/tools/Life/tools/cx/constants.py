SS_KEY_GLOBAL_ID=0x04
SS_KEY_LOW_PUSH_THRESHOLD=0x10 #(uint8_t)
SS_KEY_HIGH_PUSH_THRESHOLD=0x11 #(uint8_t)
SS_KEY_TOAST_SAMPLE_INTERVAL=0x12 #(uint32_t)
SS_KEY_REBOOT_COUNTER=0x13 #(uint16_t)
SS_KEY_BACON_SAMPLE_INTERVAL=0x14 #(uint32_t)
SS_KEY_PROBE_SCHEDULE=0x15 #(probe_schedule_t) (CXMac.h)
SS_KEY_PHOENIX_SAMPLE_INTERVAL=0x16 #(uint32_t) (phoenix.h)
SS_KEY_PHOENIX_TARGET_REFS=0x17 #(uint32_t) (phoenix.h)
SS_KEY_DOWNLOAD_INTERVAL=0x18   #(uint32_t) (router.h)
SS_KEY_MAX_DOWNLOAD_ROUNDS=0x19 #(uint8_t)

DEFAULT_SAMPLE_INTERVAL=(60*1024*10)

NS_GLOBAL=0
NS_SUBNETWORK=1
NS_ROUTER=2

CHANNEL_GLOBAL=128
CHANNEL_ROUTER=64
CHANNEL_SUBNETWORK_DEFAULT=0

MAX_REQUEST_UNIT=2000
DEFAULT_RADIO_CONFIG = {
  'probeInterval': 1024,
  'globalChannel': CHANNEL_GLOBAL,
  'subNetworkChannel': CHANNEL_SUBNETWORK_DEFAULT,
  'routerChannel': CHANNEL_ROUTER,
  'globalInvFrequency': 4,
  'subNetworkInvFrequency': 1,
  'routerInvFrequency': 1,
  'globalBW': 2,
  'subNetworkBW': 2,
  'routerBW': 2,
  'globalMaxDepth':8,
  'subNetworkMaxDepth':5,
  'routerMaxDepth': 5,
  'maxDownloadRounds':10}
BCAST_ADDR= 0xFFFF
