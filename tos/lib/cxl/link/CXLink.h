#ifndef CX_LINK_H
#define CX_LINK_H

#include "AM.h"

#ifndef CX_SCALE_TIME
#define CX_SCALE_TIME 1
#endif

#ifndef FRAMELEN_SLOW
//32k = 2**15
#define FRAMELEN_SLOW (1024UL * CX_SCALE_TIME)
#endif

#ifndef FRAMELEN_FAST_NORMAL
//6.5M = 2**5 * 5**16 * 13
#define FRAMELEN_FAST_NORMAL (203125UL * CX_SCALE_TIME)
#endif

#ifndef FRAMELEN_FAST_SHORT
//#define FRAMELEN_FAST_SHORT (84500UL * CX_SCALE_TIME)
//#define FRAMELEN_FAST_SHORT (90000UL * CX_SCALE_TIME)
//#define FRAMELEN_FAST_SHORT FRAMELEN_FAST_NORMAL
//#define FRAMELEN_FAST_SHORT (19700UL + 5000UL)
//Experiments indicate that at this length, we have very few missed tx
//deadlines at forwarders.
#define FRAMELEN_FAST_SHORT 37050UL
#endif

//TODO: these should be based on sizeof's/whether FEC is in use.
//Short packet: up to 2 bytes payload (mac header + 1 byte padding).
//extended by 6 bytes for probe timestamp
#define SHORT_PACKET 18
//Long packet: at least 64 bytes, when encoded (also: 2 byte crc)
#define LONG_PACKET 30

//worst case: 8 byte-times (preamble, sfd)
//(64/125000.0)*6.5e6=3328, round up a bit.
#define CX_CS_TIMEOUT_EXTEND 3500UL

//time from strobe command to SFD: 0.000523 S
//argh, this looks less constant than I want it to be...
#define TX_SFD_ADJUST 3346UL

//difference between transmitter SFD and receiver SFD: 60.45 fast ticks
//#define T_SFD_PROP_TIME_FAST (60UL - 12UL)
#define T_SFD_PROP_TIME_NORMAL (59UL)
#define T_SFD_PROP_TIME_FAST T_SFD_PROP_TIME_NORMAL 

#define RX_SFD_ADJUST_NORMAL (TX_SFD_ADJUST + T_SFD_PROP_TIME_NORMAL)
//#define RX_SFD_ADJUST_FAST   (TX_SFD_ADJUST + T_SFD_PROP_TIME_FAST)
#define RX_SFD_ADJUST_FAST RX_SFD_ADJUST_NORMAL  


typedef nx_struct cx_link_header {
  nx_uint8_t ttl;
  nx_uint8_t hopCount;
  nx_am_addr_t destination;
  nx_am_addr_t source;
  nx_uint16_t sn;
  nx_uint8_t bodyLen;
} cx_link_header_t;

typedef struct cx_link_metadata {
  uint8_t rxHopCount;
  uint32_t time32k;
  uint32_t timeMilli;
  uint32_t timeFast;
  bool retx;
  nx_uint32_t* tsLoc;
  bool dataPending;
  uint32_t txTime;
} __attribute__((packed)) cx_link_metadata_t;


//This flag determines whether nodes re-synch to their own SFD on
//every rx/tx or whether they use the first SFD capture as the basis
//for a periodic alarm. 
//
// Experiments indicate that re-synching to your own SFD on every
// TX/RX provides
// slightly better performance with long packets. However, short (< 64
// byte) packets show some odd behavior that is handled better with
// single-synchronization. 
//
// The same amount of time elapses
// between the alarm.fired and SFD event for every *source*
// transmission, while the forwarders initially take less time for
// this process. The forwarder time does converge to the source time
// eventually, though. By using a single synchronization point, as
// long as that is computed correctly, the transmitters will be back
// in synchronization when they converge to the source's transmission
// timing.
#ifndef SELF_SFD_SYNCH
#define SELF_SFD_SYNCH 0
#endif


#ifndef CX_MAX_DEPTH
#define CX_MAX_DEPTH 10
#endif

#ifndef POWER_ADJUST
#define POWER_ADJUST 0
#endif

#ifndef MAX_POWER
#ifdef PATABLE0_SETTING
#define MAX_POWER PATABLE0_SETTING
#else
#warning "Defining max power to be 0x8D (0 dBm)"
#define MAX_POWER 0x8D
#endif
#endif

#ifndef MIN_POWER
//0x03: -30 dBm
#define MIN_POWER 0x03
#endif

#endif
