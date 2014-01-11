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

#include "TestToast.h"
configuration TestAppC{
} implementation {
  components MainC;
  components PlatformSerialC;
  components SerialPrintfC;
  components LedsC;

  components new I2CDiscovererC();

  components TestP;

  TestP.Boot -> MainC;
  TestP.Leds -> LedsC;
  TestP.StdControl -> PlatformSerialC;
  TestP.SubUartStream -> PlatformSerialC;

  TestP.I2CDiscoverer -> I2CDiscovererC;
  components new BusPowerClientC();
  TestP.BusControl -> BusPowerClientC; 

  enum {
    ADC_TEST_ID = unique(UQ_TEST_CLIENT),
  };
  components ADCTestC;
  ADCTestC.UartStream -> TestP.UartStream[ADC_TEST_ID];
  ADCTestC.Get -> TestP.Get;
  TestP.GetDesc[ADC_TEST_ID] -> ADCTestC.GetDesc;


  enum {
    SYNCH_TEST_ID = unique(UQ_TEST_CLIENT),
  };
  components SynchTestC;
  SynchTestC.UartStream -> TestP.UartStream[SYNCH_TEST_ID];
  SynchTestC.Get -> TestP.Get;
  TestP.GetDesc[SYNCH_TEST_ID] -> SynchTestC.GetDesc;

  enum{
    TLV_STORAGE_TEST_ID = unique(UQ_TEST_CLIENT),
  };
  components TLVStorageTestC;
  TLVStorageTestC.UartStream -> TestP.UartStream[TLV_STORAGE_TEST_ID];
  TLVStorageTestC.Get -> TestP.Get;
  TestP.GetDesc[TLV_STORAGE_TEST_ID] -> TLVStorageTestC.GetDesc;

  enum{
    STORAGE_TEST_ID = unique(UQ_TEST_CLIENT),
  };
  components StorageTestC;
  StorageTestC.UartStream -> TestP.UartStream[STORAGE_TEST_ID];
  StorageTestC.Get -> TestP.Get;
  TestP.GetDesc[STORAGE_TEST_ID] -> StorageTestC.GetDesc;

}
