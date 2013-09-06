generic configuration DummyArbiterC() {
  provides interface Resource[uint8_t clientId];
  provides interface ResourceDefaultOwner;
  provides interface ResourceRequested[uint8_t id];
  provides interface ArbiterInfo;
  uses interface ResourceConfigure[uint8_t clientId];

} implementation {
  components new DummyArbiterP(1) as Arbiter;
  Resource = Arbiter;
  ResourceRequested = Arbiter;
  ResourceDefaultOwner = Arbiter;
  ArbiterInfo = Arbiter;
  ResourceConfigure = Arbiter;
    
//  components new DummyResourceQueueC() as Queue;
//  Arbiter.Queue -> Queue.FcfsQueue;

}
