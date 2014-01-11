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

interface I2CRegister{
  //The provider is saying "A transaction is starting, and you're the
  //  client being addressed. I need a buffer to read from/write to"
  //At this point, the user might call the pause command to indicate
  //  that the buffer it returns is not available yet.
  //Note that while the provider is not paused, this buffer may be
  //  read/written willy-nilly
  //isTransmit is from the perspective of the master: if it's true,
  //  then we will see more slaveTransmitRequested events within this
  //  layer
  async event uint8_t* transactionStart(bool isTransmit);

  //The provider is asking "how long is the buffer that you have
  //  given me?"
  async event uint8_t registerLen();

  //The provider is saying "This transaction is done: here's the
  //register that was written to/read from, and this is the current
  //position within it."
  //The provider will not modify this buffer again.
  async event void transactionStop(uint8_t* reg, uint8_t pos);
  
  async command error_t pause();
  async command error_t unPause();

}
