
 #include "TestbedDebug.h"
module AutoSenderP{
  uses interface Boot;
  uses interface AMSend;
  uses interface Pool<message_t>;
  uses interface CXLinkPacket;
  uses interface Timer<TMilli>;
} implementation {
  message_t* testMsg;
  uint16_t packetsQueued = 0;
  bool sending;

  event void Boot.booted(){
    if (DATA_RATE){
      testMsg = call Pool.get();
      if (testMsg){
        call Timer.startPeriodic(DATA_RATE);
      }else{
        cerror(TESTBED, "TMPE\r\n");
      }
    }else{
      cinfo(TESTBED, "Non-sender\r\n");
    }
  }

  task void sendAgain(){
   if (!sending && packetsQueued){
     error_t error;
     (call CXLinkPacket.getLinkMetadata(testMsg))->dataPending = (packetsQueued > 1);
     error = call AMSend.send(TEST_DESTINATION, testMsg,
       TEST_PAYLOAD_LEN);
     if (SUCCESS != error){
       cerror(TESTBED, "Send %x\r\n", error);
     }else{
       sending = TRUE;
     }
   }
  }

  event void Timer.fired(){
    packetsQueued ++;
    post sendAgain();
  }


  event void AMSend.sendDone(message_t* msg, error_t error){
    sending = FALSE;
    if (error == SUCCESS){
      if(packetsQueued){
        packetsQueued --;
      }
    }else{
      cerror(TESTBED, "SendDone %x\r\n", error);
    }
    post sendAgain();
  }

}
