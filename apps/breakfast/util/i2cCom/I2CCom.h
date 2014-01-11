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

#ifndef I2C_COM_H
#define I2C_COM_H

#ifndef I2C_MESSAGE_LEN
#define I2C_MESSAGE_LEN 90
#endif

typedef nx_struct i2c_message_header_t {
  nx_uint16_t slaveAddr;
  nx_uint8_t clientId;
  nx_uint8_t len;
} i2c_message_header_t;

typedef nx_union i2c_message_t{
  nx_uint8_t buf[I2C_MESSAGE_LEN + sizeof(i2c_message_header_t)];
  nx_struct{
    i2c_message_header_t header;
    nx_uint8_t buf[I2C_MESSAGE_LEN];
  } body;
} i2c_message_t; 

i2c_message_t* swapBuffer(i2c_message_t* a, i2c_message_t** b){
  i2c_message_t* tmp = *b;
  *b = a;
  return tmp;
}

#define UQ_I2C_COM_MASTER "I2CComMaster.client"
#endif
