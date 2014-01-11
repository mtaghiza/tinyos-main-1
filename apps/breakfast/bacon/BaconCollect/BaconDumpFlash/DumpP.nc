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

#include <stdio.h>
#include "decodeError.h"
#include "baconCollect.h"
#include "I2CADCReader.h"

module DumpP{
  uses interface Boot;
  uses interface Leds;

  uses interface Crc;
  uses interface LogRead;
  uses interface LogWrite;
  
  /* Timers */  
  uses interface Timer<TMilli> as WDTResetTimer;
  uses interface Timer<TMilli> as LedsTimer;


  /* UART */
  uses interface StdControl as SerialControl;
  uses interface UartStream;

 
  /* PINS */
  uses interface HplMsp430GeneralIO as CS;
  uses interface HplMsp430GeneralIO as CD;
  uses interface HplMsp430GeneralIO as FlashEnable;
  
} implementation {


  uint8_t __attribute__ ((section(".noinit"))) boot_counter;

  uint8_t printMessage(void* pl);
  uint8_t checkMessage(uint8_t* pl, bool doCrc);

  /*************************/
  uint8_t blinkTaskParameter;
  task void blinkTask();
  
  
  
  /*************************/
  /* flash read            */  
  uint32_t readCookie;
  uint32_t flashCookie;
  uint8_t readBuffer[512];

  /*************************/
  event void Boot.booted()
  {
    call FlashEnable.set();
    call FlashEnable.makeOutput();
    call FlashEnable.selectIOFunc();
        
    call SerialControl.start();
    call WDTResetTimer.startPeriodic(512);
    
    //set WDT to reset at 1 second
    WDTCTL = WDT_ARST_1000;

    /* boot sequence continues in syncDone */
    call LogWrite.sync();
  }

  /***************************************************************************/
  /* Flash                                                                   */
  /***************************************************************************/

  event void LogWrite.syncDone(error_t error) 
  { 
    uint16_t reset_vector = SYSRSTIV;
    if (reset_vector == 0x04)
      boot_counter = 0;
    else
      ++boot_counter;


    printf("root: %d %X\n\r", boot_counter, reset_vector);

    readCookie = SEEK_BEGINNING;
    flashCookie = call LogWrite.currentOffset();
    printf("write: %04X%04X\n\r", (uint16_t)(flashCookie >> 16), (uint16_t)(flashCookie & 0x0000FFFF));

    /* flash leds to signal successful boot */
    blinkTaskParameter = LEDS_LED0|LEDS_LED1|LEDS_LED2;
    post blinkTask();
  }

  
  event void LogWrite.appendDone(void* buf_, storage_len_t len, bool recordsLost, error_t error)
  {
    printf("%s : %s\n\r", __FUNCTION__, decodeError(error));
  }

  event void LogWrite.eraseDone(error_t error)
  {
    printf("%s : %s\n\r", __FUNCTION__, decodeError(error));
  }
  


  event void LogRead.seekDone(error_t err)
  {
    readCookie = call LogRead.currentOffset();
    
    call LogRead.read(readBuffer, FLASH_MAX_READ);
  }

  event void LogRead.readDone(void* buf_, storage_len_t len, error_t err)
  {
    uint8_t i;
    uint8_t sampleSize;
    uint8_t readCounter = 0;
    uint8_t * buffer = (uint8_t*) buf_;
    
//    printf("length: %u\n\r", *buffer);
//    printf("new offset: %04X%04X\n\r", (uint16_t)(readCookie >> 16), (uint16_t)(readCookie & 0x0000FFFF));

    
    /* find first record */
    for ( i = 0; i + SAMPLE_MAX_SIZE < len; i++ )
    {
      sampleSize = checkMessage(&(buffer[i]), TRUE);
      
      if (sampleSize > 0)
        break;      
    }      

    readCounter = i;

    /* print records */
    while ( (sampleSize > 0) && ( (i + sampleSize) < len) )
    {
      printMessage(&(buffer[i]));

      i += sampleSize;
      readCounter = i;

      sampleSize = checkMessage(&(buffer[i]), FALSE);
    } 
    
    readCookie += readCounter;

    if (!(len < FLASH_MAX_READ))
      call LogRead.seek(readCookie);
//      call LogRead.read(readBuffer, 255);

    call Leds.led2Toggle();
  }


  uint8_t checkMessage(uint8_t* pl, bool doCrc)
  {
    sample_header_t * headerPointer = (sample_header_t*) pl;
    
    switch (headerPointer->type)
    {
      case TYPE_SAMPLE_BACON:
        {
          bool crcPassed;
          sample_bacon_t * localPointer = (sample_bacon_t*) pl;
        
          crcPassed = (doCrc) ? (localPointer->crc == call Crc.crc16(localPointer, sizeof(sample_bacon_t) - sizeof(uint16_t))) : TRUE;

          if ( crcPassed && (headerPointer->length == sizeof(sample_bacon_t)) )
            return sizeof(sample_bacon_t);
        }

      case TYPE_SAMPLE_TOAST:
        {
          bool crcPassed;
          sample_toast_t * localPointer = (sample_toast_t*) pl;
        
          crcPassed = (doCrc) ? (localPointer->crc == call Crc.crc16(localPointer, sizeof(sample_toast_t) - sizeof(uint16_t))) : TRUE;

          if ( crcPassed && (headerPointer->length == sizeof(sample_toast_t)) )
            return sizeof(sample_toast_t);
        }
          
      case TYPE_SAMPLE_CLOCK:
        {
          bool crcPassed;
          sample_clock_t * localPointer = (sample_clock_t*) pl;
        
          crcPassed = (doCrc) ? (localPointer->crc == call Crc.crc16(localPointer, sizeof(sample_clock_t) - sizeof(uint16_t))) : TRUE;

          if ( crcPassed && (headerPointer->length == sizeof(sample_clock_t)) )
            return sizeof(sample_clock_t);
        }

      case TYPE_SAMPLE_STATUS:
        {
          bool crcPassed;
          sample_status_t * localPointer = (sample_status_t*) pl;
        
          crcPassed = (doCrc) ? (localPointer->crc == call Crc.crc16(localPointer, sizeof(sample_status_t) - sizeof(uint16_t))) : TRUE;

          if ( crcPassed && (headerPointer->length == sizeof(sample_status_t)) )
            return sizeof(sample_status_t);
        }

      default:
    }

    return 0;
  }

  uint8_t printMessage(void* pl)
  {
    sample_header_t * headerPointer;
    uint8_t i;

    headerPointer = (sample_header_t*) pl;

    printf("%3d ", headerPointer->source); 
    printf("%d ", headerPointer->type); 

    printf("%04X", (uint16_t) (headerPointer->flash >> 16));
    printf("%04X ", (uint16_t) (headerPointer->flash & 0x0000FFFF));

    printf("%3u ", headerPointer->boot); 
    printf("%9lu ", headerPointer->time);

    if (headerPointer->type == TYPE_SAMPLE_BACON)
    {
      sample_bacon_t * localPointer = (sample_bacon_t*) pl;
      printf("%5u ", localPointer->battery);
      printf("%5u ", localPointer->light);
      printf("%5u ", localPointer->temp);
      printf("%04X ", localPointer->crc);
      printf("%04X", call Crc.crc16(localPointer, sizeof(sample_bacon_t) - sizeof(uint16_t)));
      printf("\n\r");
      
      return sizeof(sample_bacon_t);
    }
    else if (headerPointer->type == TYPE_SAMPLE_TOAST)
    {
      sample_toast_t * localPointer = (sample_toast_t*) pl;

      for (i = 0; i < ADC_NUM_CHANNELS - 1; i++)
      {
        printf("%5u ", localPointer->sample[i]);
      }
      printf("%04X", (uint16_t) (localPointer->id >> 16));      
      printf("%04X ", (uint16_t) (localPointer->id & 0x0000FFFF));      
      printf("%04X ", localPointer->crc);
      printf("%04X", call Crc.crc16(localPointer, sizeof(sample_toast_t) - sizeof(uint16_t)));
      printf("\n\r");

      return sizeof(sample_toast_t);
    }
    else if (headerPointer->type == TYPE_SAMPLE_CLOCK)
    {
      sample_clock_t * localPointer = (sample_clock_t*) pl;

      printf("%5u ", localPointer->reference);
      printf("%3u ", localPointer->boot);
      printf("%9lu ", localPointer->time);
      for (i = 0; i < 7; i++)
        printf("%2u ", localPointer->rtc[i]);        
      printf(" %04X ", localPointer->crc);
      printf("%04X", call Crc.crc16(localPointer, sizeof(sample_clock_t) - sizeof(uint16_t)));
      printf("\n\r");

      return sizeof(sample_clock_t);
    }
    else if (headerPointer->type == TYPE_SAMPLE_STATUS)
    {
      sample_status_t * localPointer = (sample_status_t*) pl;

      printf("%3u ", localPointer->writeQueue);
      printf("%3u ", localPointer->sendQueue);
      printf("%9lu ", localPointer->radioOnTime);
      printf("%9lu ", localPointer->radioOffTime);
      printf("%04X ", localPointer->crc);
      printf("%04X", call Crc.crc16(localPointer, sizeof(sample_status_t) - sizeof(uint16_t)));
      printf("\n\r");

      return sizeof(sample_status_t);
    }
    else
      printf("unknown sample type: %d\n\r", headerPointer->type);

    return 0;
  }


  /***************************************************************************/
  /* Timers                                                                  */
  /***************************************************************************/
    
  event void WDTResetTimer.fired() {
    //re-up the wdt
    WDTCTL =  WDT_ARST_1000;
  }

  task void blinkTask()
  {
    call Leds.set(blinkTaskParameter);
    call LedsTimer.startOneShot(512);
  }
  
  event void LedsTimer.fired() 
  {
    if (blinkTaskParameter & LEDS_LED2)
    {
      blinkTaskParameter &= ~LEDS_LED2;
      call Leds.led2Off();
      call LedsTimer.startOneShot(256);
    }
    else if (blinkTaskParameter & LEDS_LED1)
    {
      blinkTaskParameter &= ~LEDS_LED1;
      call Leds.led1Off();
      call LedsTimer.startOneShot(256);
    }
    else 
    {
      blinkTaskParameter = 0;
      call Leds.led0Off();
    }  
  }


  /***************************************************************************/

  uint32_t readAddress = 0x0002AF54;
  uint8_t readLength = 40;
  uint16_t readNode = 0x0002;

  
  /***************************************************************************/
  /* UART                                                                    */
  /***************************************************************************/

  norace uint8_t uartByte;
  task void uartTask();

  async event void UartStream.receivedByte(uint8_t byte) {

    uartByte = byte;
    
    post uartTask();
  }
  
  task void uartTask()
  {  
    switch ( uartByte ) {
   
      case '0':
        break;

      case '1':
        break;
   
      case 't':
        break;

      case 'b':
        break;

      case 'e':
        printf("Erase: ");
        call LogWrite.erase();
        break;

      case 'd':
        call LogRead.seek(readCookie);
        break;

      case 's':
        printf("sync: ");
        call LogWrite.sync();
        break;

      case 'z':
        break;

      case 'x':
        break;

      case 'c':
        break;

      case 'q':
        WDTCTL = 0;
        break;

      case '\r':
        printf("\n\r");
        break;

      default:
        printf("%c", uartByte);
        break;
    }
  }
  
  async event void UartStream.receiveDone( uint8_t* buf_, uint16_t len,
    error_t error ){}
  async event void UartStream.sendDone( uint8_t* buf_, uint16_t len,
    error_t error ){}


}

