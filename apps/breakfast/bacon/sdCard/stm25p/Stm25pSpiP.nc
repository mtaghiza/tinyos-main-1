/*
 * Copyright (c) 2005-2006 Arch Rock Corporation
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the Arch Rock Corporation nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE
 * ARCHED ROCK OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE
 */

/**
 * @author Jonathan Hui <jhui@archrock.com>
 * @version $Revision$ $Date$
 */


module Stm25pSpiP {

  provides interface Resource as ClientResource;
  provides interface Stm25pSpi as Spi;

  uses interface Resource as SDResource;

  uses interface SDCard;
  uses interface Leds;


}

implementation {

  norace stm25p_addr_t m_addr;

  task void bulkEraseTask();


  async command error_t ClientResource.request() {

#ifdef STM25PSPIP_DEBUG
    printf("%s\n\r", __FUNCTION__);
    printfflush();
#endif

    return call SDResource.request();
  }

  async command error_t ClientResource.immediateRequest() {

#ifdef STM25PSPIP_DEBUG
    printf("%s\n\r", __FUNCTION__);
    printfflush();
#endif
    
    return call SDResource.immediateRequest();
  }
  
  async command error_t ClientResource.release() {

#ifdef STM25PSPIP_DEBUG
    printf("%s\n\r", __FUNCTION__);
    printfflush();
#endif
    
    return call SDResource.release();
  }

  async command uint8_t ClientResource.isOwner() {

#ifdef STM25PSPIP_DEBUG
    printf("%s\n\r", __FUNCTION__);
    printfflush();
#endif
    
    return call SDResource.isOwner();
  }

  event void SDResource.granted() {

#ifdef STM25PSPIP_DEBUG
    printf("%s\n\r", __FUNCTION__);
    printfflush();
#endif
    
    signal ClientResource.granted();
  }


  command error_t Spi.powerDown() {

#ifdef STM25PSPIP_DEBUG
    printf("%s\n\r", __FUNCTION__);
    printfflush();
#endif
    
//    return call SDCard.powerDown();
    return SUCCESS;
  }

  command error_t Spi.powerUp() {

#ifdef STM25PSPIP_DEBUG
    printf("%s\n\r", __FUNCTION__);
    printfflush();
#endif
    
//    return call SDCard.powerUp();
    return SUCCESS;
  }


  command error_t Spi.read( stm25p_addr_t addr, uint8_t* buf, stm25p_len_t len ) 
  {

#ifdef STM25PSPIP_DEBUG
    printf("%s: %lX, %ld\n\r", __FUNCTION__, addr, len);
    printfflush();
#endif
    
    call SDCard.read(addr, buf, len);

    // note: old newRequest() always return SUCCSS 
    return SUCCESS;
  }

  event void SDCard.readDone(uint32_t addr, uint8_t*buf, uint16_t len, error_t error)
  {    

#ifdef STM25PSPIP_DEBUG
    printf("%s: %lX, %d\n\r", __FUNCTION__, addr, len);
    printfflush();
#endif

    signal Spi.readDone( addr, buf, len, SUCCESS );
    // note: old readDone always return SUCCSS 
  }

  command error_t Spi.pageProgram( stm25p_addr_t addr, uint8_t* buf, stm25p_len_t len ) 
  {

#ifdef STM25PSPIP_DEBUG
    printf("%s: %lX, %ld\n\r", __FUNCTION__, addr, len);
    printfflush();
#endif
    
    // note: old pageProrgam always return SUCCSS 
    call SDCard.write(addr, buf, len);
    
    return SUCCESS;
  }

  event void SDCard.writeDone(uint32_t addr, uint8_t*buf, uint16_t len, error_t error)
  {

#ifdef STM25PSPIP_DEBUG
    printf("%s: %lX, %d\n\r", __FUNCTION__, addr, len);
    printfflush();
#endif
    
    // note: old pageProrgamDone always return SUCCSS 
    signal Spi.pageProgramDone( addr, buf, len, SUCCESS );
  }  


  #warning Stm25pSpi.computeCrc not implemented  
  command error_t Spi.computeCrc( uint16_t crc, stm25p_addr_t addr, stm25p_len_t len ) 
  {

#ifdef STM25PSPIP_DEBUG
    printf("%s\n\r", __FUNCTION__);
    printfflush();
#endif
    
    // note: function only used by BlockStorage and not LogStorage
    return FAIL;
  }
  


  command error_t Spi.sectorErase( uint8_t sector ) 
  {

#ifdef STM25PSPIP_DEBUG
    printf("%s: %d\n\r", __FUNCTION__, sector);
    printfflush();
#endif
    
    m_addr = (stm25p_addr_t)sector << STM25P_SECTOR_SIZE_LOG2;

    call SDCard.eraseSectors(m_addr, STM25P_SECTOR_SIZE / 512);

    // note: old sectorErase always return SUCCSS     
    return SUCCESS;
  }

  event void SDCard.eraseSectorsDone()
  {
    signal Spi.sectorEraseDone( m_addr >> STM25P_SECTOR_SIZE_LOG2, SUCCESS );
  }
  
  event void SDCard.flushDone()
  { ; }

  command error_t Spi.bulkErase() 
  {

#ifdef STM25PSPIP_DEBUG
    printf("%s\n\r", __FUNCTION__);
    printfflush();
#endif

    call SDCard.eraseSectors(0,0);
    post bulkEraseTask();
    
    // note: old bulkErase always return SUCCSS     
    return SUCCESS;
  }

  task void bulkEraseTask()
  {
    signal Spi.bulkEraseDone( SUCCESS );
  }


}
