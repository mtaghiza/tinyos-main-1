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

interface I2CSlave{
  command error_t setOwnAddress(uint16_t addr);
  command error_t enableGeneralCall();
  command error_t disableGeneralCall();

  //signalled when a byte is sitting in the RXBUF
  //returns TRUE: The signalled code called slaveReceive to read from
  //  the RXBUF already.
  //returns FALSE: The signalled code is not ready to read from the
  //  RXBUF yet. If false is returned, the signalled code MUST call
  //  slaveReceive to read the byte from the buffer. Until this
  //  occurs, the bus will be stalled. 
  async event bool slaveReceiveRequested();

  //retrieve the byte from the RXBUF. Should be called only once
  // for each time that slaveReceiveRequested() is signalled
  async command uint8_t slaveReceive();

  //signalled when a byte is expected in TXBUF.
  // return TRUE if you plan to write to it, FALSE otherwise
  async event bool slaveTransmitRequested();
  async command void slaveTransmit(uint8_t data);

  //should these return error so we can say "no, I'm not going to be a
  //slave right now"?
  async event void slaveStart(bool isGeneralCall);
  //or maybe we should pass an error to slaveStop so that the top
  //level can know that it ended abnormally
  async event void slaveStop();
}
