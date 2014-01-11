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


module UartEchoP {
  uses {
    interface Boot;

    interface Leds;    

    interface StdControl as SerialControl;
    interface StdOut;

    interface Resource;
    interface UartStream as SecondUartStream;

  }  
  
} implementation {


  /***************************************************************************/
  
  /***************************************************************************/
  /* BOOT                                                                    */
  /***************************************************************************/

  event void Boot.booted() 
  {
    call SerialControl.start();

    if (!call Resource.isOwner())
    {
      call Resource.request();      
    }

//    call StdOut.print("UartEcho\n\r");
  }


  event void Resource.granted() 
  {
  }

  /***************************************************************************/
  /* SERIAL                                                                  */
  /***************************************************************************/

  char tmpchar;

  task void StdOutTask()
  {    
    uint8_t str[2];    
    atomic str[0] = tmpchar;
    
    switch(str[0]) {
    
      case '\r':  
                  call SecondUartStream.send("\n\r", 2);

//                  call StdOut.print("\n\r");
                  break;

      default:    
                  str[1] = '\0';
                  call SecondUartStream.send(str, 1);
//                  call StdOut.print(str);
                  break;
     }
  }
  
  /* incoming serial data */
  async event void StdOut.get(uint8_t data) 
  {
    call Leds.led2Toggle();

    tmpchar = data;
    
    post StdOutTask();
  }



  /***************************************************************************/


  async event void SecondUartStream.sendDone( uint8_t * buf, uint16_t len, error_t error ) 
  {    
  }

  async event void SecondUartStream.receiveDone( uint8_t* buf, uint16_t len, error_t error ) 
  {

  }

  /* incoming serial data */
  async event void SecondUartStream.receivedByte(uint8_t data) 
  {
    char str[2];

    str[0] = data;    
    str[1] = '\0';

    call Leds.led1Toggle();

    /* local echo */
//    call SecondUartStream.send(str, 1);

    /* remote echo */
    call StdOut.print(str);
  }



  /***************************************************************************/
  /***************************************************************************/
}
