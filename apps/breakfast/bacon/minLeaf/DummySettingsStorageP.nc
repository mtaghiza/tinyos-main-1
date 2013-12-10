module DummySettingsStorageP{
  provides interface SettingsStorage;
} implementation {
  command error_t SettingsStorage.get(uint8_t key, void* val, uint8_t len){
    return EINVAL;
  }
  command error_t SettingsStorage.set(uint8_t key, void* val, uint8_t len){
    return SUCCESS;
  }
  command error_t SettingsStorage.clear(uint8_t key){
    return SUCCESS;
  }
}
