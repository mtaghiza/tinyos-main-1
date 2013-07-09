#include "AM.h"

configuration RouterAMQueueP {
  provides interface Send[uint8_t client];
}

implementation {
  enum {
    NUM_CLIENTS = uniqueCount(UQ_ROUTER_SEND)
  };
  
  components new AMQueueImplP(NUM_CLIENTS), ActiveMessageC;

  Send = AMQueueImplP;
  AMQueueImplP.AMSend -> ActiveMessageC.AMSend[NS_ROUTER];
  AMQueueImplP.AMPacket -> ActiveMessageC;
  AMQueueImplP.Packet -> ActiveMessageC;

  AMQueueImplP.CTS -> ActiveMessageC.CTS[NS_ROUTER];
  
}




