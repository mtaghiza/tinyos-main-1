generic module DummyResourceQueueC(uint8_t size) @safe() {
  provides {
    interface Init;
    interface ResourceQueue as FcfsQueue;
  }
}
implementation {
  enum {NO_ENTRY = 0xFF};
  bool queued = FALSE;
  resource_client_id_t qe = NO_ENTRY;

  command error_t Init.init() {
    return SUCCESS;
  }
  async command bool FcfsQueue.isEmpty() {
    return !queued;
  }
  async command bool FcfsQueue.isEnqueued(resource_client_id_t id) {
    return queued==id;
  }
  async command resource_client_id_t FcfsQueue.dequeue() {
    resource_client_id_t ret = qe;
    queued = FALSE;
    qe = NO_ENTRY;
    return ret;
  }

  async command error_t FcfsQueue.enqueue(resource_client_id_t id) {
    if (queued){
      return EBUSY;
    }else{
      queued = TRUE;
      qe = id;
      return SUCCESS;
    }
  }
}
