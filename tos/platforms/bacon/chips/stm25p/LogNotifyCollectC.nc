configuration LogNotifyCollectC{
  uses interface Notify<uint8_t> as SubNotify[volume_id_t volume_id];
  provides interface Notify<uint8_t> as Notify[volume_id_t volume_id];
} implementation {
  Notify = SubNotify;
}
