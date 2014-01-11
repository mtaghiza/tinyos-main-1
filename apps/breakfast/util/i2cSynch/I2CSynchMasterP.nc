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

#include "I2CCom.h"
#include "I2CSynch.h"

module I2CSynchMasterP{
  uses interface I2CComMaster;
  uses interface LocalTime<T32khz> as  LocalTime32k;
  uses interface LocalTime<TMilli> as LocalTimeMilli;
  provides interface I2CSynchMaster;
} implementation {
  uint32_t localTime32k;
  uint32_t localTimeMilli;
  i2c_message_t msg_internal;
  i2c_message_t* msg = &msg_internal;
  bool busy;

  command error_t I2CSynchMaster.synch(uint16_t slaveAddr){
    error_t ret;
    synch_message_t* payload = (synch_message_t*) call I2CComMaster.getPayload(msg);
    if (busy){
      return EBUSY;
    }
    payload->cmd = SYNCH_CMD_READY;
    ret = call I2CComMaster.send(slaveAddr, msg, sizeof(synch_message_t));
    if (ret == SUCCESS){
      busy = TRUE;
    }
    return ret;
  }

  task void readTask();

  event void I2CComMaster.sendDone(error_t error, i2c_message_t* msg_){
    if (error == SUCCESS){
      post readTask();
    } else {
      synch_tuple_t ret = {0, 0};
      busy = FALSE;
      signal I2CSynchMaster.synchDone(error,
        msg->body.header.slaveAddr, ret);
    }
  }

  task void readTask(){
    error_t error;
    synch_tuple_t ret = {0, 0};
    localTime32k = call LocalTime32k.get();
    localTimeMilli = call LocalTimeMilli.get();
    error = call I2CComMaster.receive(msg->body.header.slaveAddr, msg,
      sizeof(nx_uint32_t));
    if (error != SUCCESS){
      busy = FALSE;
      signal I2CSynchMaster.synchDone(error, msg->body.header.slaveAddr, ret);
    }
  }

  event void I2CComMaster.receiveDone(error_t error, i2c_message_t*
  msg_){
    synch_tuple_t ret = {0, 0};
    if (error != SUCCESS){
      busy = FALSE;
      signal I2CSynchMaster.synchDone(error,
        msg->body.header.slaveAddr, ret);
      return;
    } else {
      synch_response_t* pl = (synch_response_t*) call
        I2CComMaster.getPayload(msg);
      ret.localTimeMilli = localTimeMilli;
      ret.localTime32k = localTime32k;
      ret.remoteTime = pl->remoteTime;
      busy = FALSE;
      signal I2CSynchMaster.synchDone(SUCCESS,
        msg->body.header.slaveAddr, ret);
    }
  }

}
