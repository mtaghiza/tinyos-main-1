generic configuration DummyArbiterC() {
  provides interface Resource[uint8_t clientId];
  provides interface ResourceDefaultOwner;
  provides interface ResourceRequested[uint8_t id];
  provides interface ArbiterInfo;
  uses interface ResourceConfigure[uint8_t clientId];

} implementation {
  components new NoArbiterC();
  Resource[0] = NoArbiterC.Resource;
  ResourceConfigure[0] = NoArbiterC.ResourceConfigure;
  //TODO: ResourceDefaultOwner?
  //TODO: ResourceRequested: never signal
  //TODO: ArbiterInfo

}
