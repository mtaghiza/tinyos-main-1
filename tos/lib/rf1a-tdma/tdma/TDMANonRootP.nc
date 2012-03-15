module TDMANonRootP{
  uses interface Send;
  uses interface TDMARootControl;
} implementation {
  event void Send.sendDone(message_t* msg, error_t error){ }
  event bool TDMARootControl.isRoot(){
    return FALSE;
  }
}
