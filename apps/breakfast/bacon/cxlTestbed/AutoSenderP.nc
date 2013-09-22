module AutoSenderP{
  uses interface Boot;
  uses interface AMSend;
  uses interface Pool<message_t>;
} implementation {

  event void Boot.booted(){
    if (IS_SENDER){
      //TODO: get message from pool
      //TODO: set up message
      //TODO: set data-pendng bit
      call AMSend.send()
    }
  }

  event void AMSend.sendDone(){
    //TODO: post task to send it again
  }

}
