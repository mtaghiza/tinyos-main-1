#include "AM.h"

configuration SubNetworkAMQueueP {
  provides interface Send[uint8_t client];
}

implementation {
  enum {
    NUM_CLIENTS = uniqueCount(UQ_SUBNETWORK_SEND)
  };
  
  components new AMQueueImplP(NUM_CLIENTS), ActiveMessageC;

  Send = AMQueueImplP;
  AMQueueImplP.AMSend -> ActiveMessageC.AMSend[NS_SUBNETWORK];
  AMQueueImplP.AMPacket -> ActiveMessageC;
  AMQueueImplP.Packet -> ActiveMessageC;

  AMQueueImplP.CTS -> ActiveMessageC.CTS[NS_SUBNETWORK];
  
}



