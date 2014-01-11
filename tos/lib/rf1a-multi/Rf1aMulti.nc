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

/*
 * Interface for allowing a single radio stack to switch modulation
 * schemes/data rates/ etc. The available configurations are expected
 * to be defined at compile time. This interface provides a
 * streamlined mechanism for switching between them and 
 * ensuring that configurations are changed only when it's "safe"
 */
interface Rf1aMulti {
  /** @return Total number of configurations available */
  command uint8_t getNumConfigs();

  /** Set the active configuration index
   * @return FAIL if radio is not able to handle this config change at
   * the moment.
   */
  command error_t setConfig(uint8_t configId);

  /**
   * @return The index of the currently-active configuration.
   */
  command uint8_t getConfig();
  
  /**
   * @return the (hopefully) globally-unique ID of the
   * currently-active configuration
   */
  command uint16_t getConfigId();

  /**
   *  set the desired configuration by unique ID.
   *  @return SUCCESS if the specified ID was wired to at least one
   *  sub-configuration. Return EINVAL if it was not.
   */
  command error_t setConfigId(uint16_t id);
}
