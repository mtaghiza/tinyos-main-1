/*
 * Copyright (c) 2014 Johns Hopkins University.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
*/

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
  command error_t get(uint8_t key, void* val, uint8_t len);

  /**
   *  Set the value of a stored setting (key, value) pair. Will
   *  replace the previously-stored value if it exists.
   *  @param key The unique identifier for this setting.
   *  @param val Pointer to the value to be stored
   *  @param len The length of the data to be stored.
   *  @return SUCCESS if the value could be written/updated. ESIZE if
   *          there is not enough space left to store this value.
   */
  command error_t set(uint8_t key, void* val, uint8_t len);

  /**
   *  Remove a (key, value) pair from the settings storage.
   *  @param key Unique ID of the key to be cleared.
   *  @return EINVAL if the key is not present. SUCCESS if it could be
   *          cleared.
   */
  command error_t clear(uint8_t key);
}
