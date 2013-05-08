#ifndef CX_TRANSPORT_H
#define CX_TRANSPORT_H

typedef nx_struct cx_transport_header {
  nx_uint8_t tproto;
  nx_uint16_t distance;
} cx_transport_header_t;

typedef nx_struct cx_ack {
  nx_uint8_t distance;
} cx_ack_t;

#define AM_CX_RR_ACK_MSG 0xC5

#define CX_TP_FLOOD_BURST 0x00
#define CX_TP_RR_BURST 0x01
#define CX_TP_SCHEDULED 0x02

#define CX_SP_DATA  0x00
#define CX_SP_SETUP 0x10
#define CX_SP_ACK   0x20

#define NUM_RX_TRANSPORT_PROTOCOLS 2

//upper nibble is available for distinguishing data/ack/setup, etc
#define CX_TP_PROTO_MASK 0x0F
#define CX_INVALID_TP 0xFF
#define CX_INVALID_DISTANCE 0xFF

//default frame len is 2^10 * 2^-15 = 2^-5 S
//set retry to 1/4 frame len: 2^-7 = 2^-10 * X
//                            2^-7 * 2^10  = 2^3 = 8
#ifndef TRANSPORT_RETRY_TIMEOUT
#define TRANSPORT_RETRY_TIMEOUT 8UL
#endif

//retry up to 4x per frame. if we still can't schedule after 2
//frames, throw in the towel.
#ifndef TRANSPORT_RETRY_THRESHOLD
#define TRANSPORT_RETRY_THRESHOLD 8
#endif

#endif
