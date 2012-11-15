#!/bin/bash
echo "//Begin Auto-generated message stubs (see genStubs.sh)"

grep 'AM' ctrl_messages.h | grep 'CMD' | awk '{print $1}'| while read amId
do
  ca=$(echo $amId | tr '[:upper:]' '[:lower:]')
  typeRoot=$(echo $ca | rev | cut -d '_' -f 1,2 --complement | rev | cut -d '_' -f 1 --complement)
  ca="$(echo $typeRoot | sed -re 's/(^|_)([a-z])/\u\2/g')"
  cmdType=${typeRoot}_cmd_msg_t
  responseType=${typeRoot}_response_msg_t
  cmdMsg=${ca}_cmd_msg;
  responseMsg=${ca}_response_msg;
cat <<EOF
  task void respond${ca}();

  event message_t* ${ca}CmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    currentCommandType = call AMPacket.type(msg_);
    if (cmdMsg != NULL){
      printf("RX: ${ca}");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        if (call LastSlave.get() == 0){
          loadTLVError = EOFF;
          post handleLoaded();
          return msg_;
        }else{
          message_t* ret = call Pool.get();
          responseMsg = call Pool.get();
          cmdMsg = msg_;
          post respond${ca}();
          return ret;
        }
      }else{
        printf("RX: ${ca}");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respond${ca}(){
    ${cmdType}* commandPl = (${cmdType}*)(call Packet.getPayload(cmdMsg, sizeof(${cmdType})));
    ${responseType}* responsePl = (${responseType}*)(call Packet.getPayload(responseMsg, sizeof(${responseType})));
    //TODO: other processing logic
    responsePl->error = FAIL;
    call ${ca}ResponseSend.send(0, responseMsg, sizeof(${responseType}));
  }

  event void ${ca}ResponseSend.sendDone(message_t* msg, 
      error_t error){
    call Pool.put(responseMsg);
    call Pool.put(cmdMsg);
    cmdMsg = NULL;
    responseMsg = NULL;
    printf("Response sent\n");
    printfflush();
  }


EOF
done

echo "//End auto-generated message stubs"
