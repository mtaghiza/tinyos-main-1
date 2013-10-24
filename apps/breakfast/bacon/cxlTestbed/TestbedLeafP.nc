module TestbedLeafP{
  uses interface DownloadNotify;
  uses interface AMSend;
  uses interface Pool<message_t>;
  uses interface Get<am_addr_t>;
  uses interface CXLinkPacket;
  uses interface Packet;
} implementation {
  message_t* testMsg = NULL;
  uint16_t packetsQueued = 0;

  task void sendAgain(){
    if (!testMsg){
      if (packetsQueued){
        testMsg = call Pool.get();
        if (!testMsg){
          cerror(TESTBED, "Leaf Pool Empty\r\n");
        }else{
          error_t error;
          call Packet.clear(testMsg);
          (call CXLinkPacket.getLinkMetadata(testMsg))->dataPending = (packetsQueued > 1);
          error = call AMSend.send(call Get.get(), testMsg,
            TEST_PAYLOAD_LEN);
           if (SUCCESS != error){
             cerror(TESTBED, "Send %x\r\n", error);
            }
        }
      }
    }
  }

  event void AMSend.sendDone(message_t* msg, error_t error){
    if (error == SUCCESS){
      if (packetsQueued){
        packetsQueued --;
        cinfo(TESTBED, "PQ %u\r\n", packetsQueued);
      }
    }
    call Pool.put(msg);
    testMsg = NULL;
    post sendAgain();
  }

  event void DownloadNotify.downloadStarted(){
    packetsQueued += PACKETS_PER_DOWNLOAD;
    post sendAgain();
  }

  event void DownloadNotify.downloadFinished(){}
}
