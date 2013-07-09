#include "AM.h"

configuration GlobalAMQueueP {
  provides interface Send[uint8_t client];
}

implementation {
  enum {
    NUM_CLIENTS = uniqueCount(UQ_GLOBAL_SEND)
  };
  
  components new AMQueueImplP(NUM_CLIENTS), ActiveMessageC;

  Send = AMQueueImplP;
  AMQueueImplP.AMSend -> ActiveMessageC.AMSend[NS_GLOBAL];
  AMQueueImplP.AMPacket -> ActiveMessageC;
  AMQueueImplP.Packet -> ActiveMessageC;

  AMQueueImplP.CTS -> ActiveMessageC.CTS[NS_GLOBAL];
  
}


