interface SettingsStorage {
  /**
   *  Retrieve a stored setting by key.
   *  @param key The unique identifier for this setting.
   *  @param val A pointer to the location where the retrieved value
   *             should be stored.
   *  @param len The length of the data to be retrieved.
   *  @return EINVAL if the key is not present. ESIZE if the specified
   *          size did not match the size of the stored value. SUCCESS
   *          if the key was found and its size was correct (contents
   *          copied to val).
   */
  command error_t get(uint8_t key, uint8_t* val, uint8_t len);

  /**
   *  Set the value of a stored setting (key, value) pair. Will
   *  replace the previously-stored value if it exists.
   *  @param key The unique identifier for this setting.
   *  @param val Pointer to the value to be stored
   *  @param len The length of the data to be stored.
   *  @return SUCCESS if the value could be written/updated. ESIZE if
   *          there is not enough space left to store this value.
   */
  command error_t set(uint8_t key, uint8_t* val, uint8_t len);

  /**
   *  Remove a (key, value) pair from the settings storage.
   *  @param key Unique ID of the key to be cleared.
   *  @return EINVAL if the key is not present. SUCCESS if it could be
   *          cleared.
   */
  command error_t clear(uint8_t key);
}
