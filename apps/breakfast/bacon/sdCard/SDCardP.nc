// $Id: SdP.nc,v 1.5 2006/12/12 18:22:50 vlahan Exp $
/*									tab:4
 */

/**
 *  Module d'exploitation carte SD.
 *
 *  @author Gwenhaël GOAVEC-MEROU
 *  @version 1.0 
 *  @date   Nov 09 2008
 *
 **/

#include "MMC.h"

module SDCardP {
  provides interface Init;
  provides interface Resource;
  provides interface SDCard;

  uses interface Resource as SpiResource;
  uses interface SpiByte;
  uses interface SpiPacket;      
  uses interface GeneralIO as Select;

  uses interface HplMsp430GeneralIO as CardDetect;

  uses interface GeneralIO as Power;
  uses interface Alarm<TMilli, uint16_t> as PowerTimeout;
}

implementation {

#define BLOCK_SIZE (512UL)
#define BLOCK_MASK (BLOCK_SIZE - 1)
#define INVALID_ADDRESS (0xFFFFFFFF)

#define R1_IN_IDLE_STATE    0x01
#define R1_ERASE_RESET      0x02
#define R1_ILLEGAL_COMMAND  0x04
#define R1_COM_CRC_ERROR    0x08
#define R1_ERASE_SEQ_ERROR  0x10
#define R1_ADDRESS_ERROR    0x20
#define R1_PARAMETER_ERROR  0x40
#define MMC_BUSY 0x00

	enum {
      SD_NOINIT = 0,
      SD_IDLE = 1,
      SD_ERASE,
      SD_WRITE_UPDATE_CACHE,
      SD_WRITE_FLUSH_CACHE_BEFORE_READ,
      SD_WRITE_FLUSH_CACHE,
      SD_WRITE_FLUSH_BEFORE_POWER,
      SD_WRITE_WRITE_TO_CACHE,
      SD_READ_FROM_SD_CARD,
      SD_READ_FROM_CACHE,
  };

  uint8_t readBlock(const uint32_t address, const uint16_t count, uint8_t *pBuffer);
  uint8_t writeBlock(const uint32_t address, uint8_t *pBuffer);
  uint8_t eraseSectors(uint32_t sectorStart, uint32_t sectorEnd);

//  uint32_t readCardSize(void);
  uint8_t mmcSetBlockLength(const uint16_t blocklength);
//  uint8_t readRegister(const uint8_t cmd_register, const uint16_t length, uint8_t *pBuffer);

//  uint8_t mmcGetResponse(void);
//  uint8_t mmcGetXXResponse(const uint8_t resp);
  void mmcCheckBusy(void);
  
  uint8_t reset();
  uint16_t mmcSendCmd(uint8_t cmd, uint32_t data, uint8_t crc);

  norace uint8_t sdState = SD_NOINIT;

  norace uint32_t m_readAddr;
  norace uint8_t* m_readBuf;
  norace uint16_t m_readLen;

  norace uint32_t m_writeAddr;
  norace uint8_t* m_writeBuf; 
  norace uint16_t m_writeLen;

  norace uint8_t* m_txBuf;
  norace uint8_t* m_rxBuf;
  norace uint16_t m_len;
  norace error_t m_error;
  
  norace uint32_t m_sectorStart;
  norace uint32_t m_sectorEnd;
  task void clearSectorsTask();
  task void spiSendDoneTask();

  task void writeToCacheTask();
  task void writeToSDCardTask();
  task void readFromCacheTask();
  task void readFromSDCardTask();


  typedef struct cache_block_t {
    uint32_t address;
    uint8_t block[BLOCK_SIZE];
    bool dirty;
  } cache_block_t;

  norace cache_block_t m_cache;

  /***************************************************************************/
  /***************************************************************************/
  /***************************************************************************/

  command error_t Init.init() 
  {
    call Power.clr();
    call Power.makeOutput();

    call Select.set();
    call Select.makeOutput();      

//    call CardDetect.makeInput();

    m_cache.address = INVALID_ADDRESS;
    m_cache.dirty = FALSE;
    
    printf("cache: %p\n\r", m_cache.block);    
    
    return SUCCESS;
  }

  async event void PowerTimeout.fired()
  {
    sdState = SD_NOINIT;
    call Power.clr();

    printf("%s\n\r", __FUNCTION__);
    printfflush();
  }

  
  async command error_t Resource.request() 
  {
    error_t error = FAIL;
    
//    call CardDetect.setResistor(MSP430_PORT_RESISTOR_PULLUP);

//    if(call CardDetect.get())
      error = call SpiResource.request();
//    else
//      error = FAIL;

//    call CardDetect.setResistor(MSP430_PORT_RESISTOR_OFF);

    return error;
  }

  async command error_t Resource.immediateRequest() 
  {
    error_t error = FAIL;
    
//    call CardDetect.setResistor(MSP430_PORT_RESISTOR_PULLUP);

//    if(call CardDetect.get())
//    {
      error = call SpiResource.immediateRequest();

      if (error == SUCCESS)
        call PowerTimeout.stop();
//    }
//    else
//      error = FAIL;
      
//    call CardDetect.setResistor(MSP430_PORT_RESISTOR_OFF);

    return error;
  }

  async command error_t Resource.release() {   
  
    printf("%s\n\r", __FUNCTION__);
    printfflush();
    
    return call SpiResource.release();
  }

  async command bool Resource.isOwner() {
    return call SpiResource.isOwner();
  }


  event void SpiResource.granted()
  { 
    printf("%s\n\r", __FUNCTION__);
    printfflush();

    if (sdState == SD_NOINIT)
    {
      sdState = SD_IDLE;
      call SDCard.powerUp();
      
      reset(); 
    }

    signal Resource.granted();    
  }

  /***************************************************************************/
  /***************************************************************************/
  /***************************************************************************/

  async event void SpiPacket.sendDone( uint8_t* txBuf, uint8_t* rxBuf, uint16_t len, error_t error)
  {
    m_txBuf = txBuf;
    m_rxBuf = rxBuf;
    m_len = len;
    m_error = error;
    
    post spiSendDoneTask();
  }  


  task void spiSendDoneTask()  
  {   
    // put CRC bytes (not really needed by us, but required by MMC)
    call SpiByte.write(DUMMY_CHAR);
    call SpiByte.write(DUMMY_CHAR);


    switch(sdState)
    {
      case SD_READ_FROM_SD_CARD:                

                    call Select.set();

                    // give the MMC the required clocks to finish up 
                    call SpiByte.write(DUMMY_CHAR);

                    printf("SDCardP__SDCard__readDone: %lX, %d\n\r", m_readAddr, m_len);
                    printfflush();

                    sdState = SD_IDLE;
                    signal SDCard.readDone(m_readAddr, m_rxBuf, m_len, m_error);
                    break;

      case SD_WRITE_UPDATE_CACHE:

                    call Select.set();

                    // give the MMC the required clocks to finish up 
                    call SpiByte.write(DUMMY_CHAR);

                    printf("SDCardP__SDCard__updateCache: %lX, %d\n\r", m_readAddr, m_len);
                    printfflush();

                    // update cache address, m_readAddr is the block address
                    m_cache.address = m_readAddr;
                    // m_cache.dirty = FALSE; // redundant, we are modifying the cache immediately

                    // read block from SD card to cache
                    // continue write operation by copying write buffer to cache
                    sdState = SD_WRITE_WRITE_TO_CACHE;
                    post writeToCacheTask();
                    break;                    

      case SD_WRITE_FLUSH_CACHE_BEFORE_READ:

                    // write status response      
                    call SpiByte.write(DUMMY_CHAR);

                    // wait until the SD card is finished writing
                    mmcCheckBusy();

                    call Select.set();

                    // give the MMC the required clocks to finish up 
                    call SpiByte.write(DUMMY_CHAR);

                    printf("SDCardP__SDCard__cacheFlushedRead: %lX, %d\n\r", m_cache.address, m_len);
                    printfflush();
      
                    sdState = SD_WRITE_UPDATE_CACHE;
                    post readFromSDCardTask();         
                    break;
                    
      case SD_WRITE_FLUSH_CACHE:

                    // write status response      
                    call SpiByte.write(DUMMY_CHAR);

                    // wait until the SD card is finished writing
                    mmcCheckBusy();

                    call Select.set();

                    // give the MMC the required clocks to finish up 
                    call SpiByte.write(DUMMY_CHAR);

                    printf("SDCardP__SDCard__cacheFlushed: %lX, %d\n\r", m_writeAddr, m_len);
                    printfflush();

                    sdState = SD_IDLE;
                    m_cache.dirty = FALSE;                    
                    break;
      
      default:
                    break;
    }

  }

  /***************************************************************************/
  /* SDCard                                                                    */
  /***************************************************************************/

  async command error_t SDCard.powerDown() 
  {
    call PowerTimeout.start(10);

    printf("%s\n\r", __FUNCTION__);
    printfflush();

    return SUCCESS;
  }

  async command error_t SDCard.powerUp() 
  {
    call PowerTimeout.stop();
    call Power.set();

    printf("%s\n\r", __FUNCTION__);
    printfflush();

    return SUCCESS;
  }


  /***************************************************************************/

  task void readFromCacheTask()
  {
    uint16_t inBlock = m_readAddr & BLOCK_MASK;
    
    memcpy(m_readBuf, m_cache.block + inBlock, m_readLen);

    sdState = SD_IDLE;
    signal SDCard.readDone(m_readAddr, m_readBuf, m_readLen, SUCCESS);
  }

  task void readFromSDCardTask()
  {
    printf("%s: %lX, %d, %p\n\r", __FUNCTION__, m_readAddr, m_readLen, m_readBuf);
    printfflush();

    readBlock(m_readAddr, m_readLen, m_readBuf);
  }

  async command error_t SDCard.read(uint32_t addr, uint8_t *buf, uint16_t count) 
  {
    uint16_t inBlock = addr & BLOCK_MASK;
    uint16_t length = ( (inBlock + count) > BLOCK_SIZE) ? (BLOCK_SIZE - inBlock) : count;

    if (sdState == SD_IDLE)
    {    
      uint32_t blockAddress = addr & ~BLOCK_MASK;

      m_readAddr = addr;
      m_readLen = length;
      m_readBuf = buf;

      printf("%s: %lX, %d\n\r", __FUNCTION__, addr, length);
      printfflush();

      if (m_cache.address == blockAddress)
      {
        sdState = SD_READ_FROM_CACHE;
        post readFromCacheTask();
      }
      else
      {
        sdState = SD_READ_FROM_SD_CARD;
        post readFromSDCardTask();
      }
      
      return SUCCESS;    
    }

    return FAIL;    
  }



  /***************************************************************************/
  /***************************************************************************/
  /***************************************************************************/

  task void writeToCacheTask()
  {
    uint16_t inBlock = m_writeAddr & BLOCK_MASK;
    
    memcpy(m_cache.block + inBlock, m_writeBuf, m_writeLen);
    m_cache.dirty = TRUE;

    sdState = SD_IDLE;
    signal SDCard.writeDone(m_writeAddr, m_writeBuf, m_writeLen, SUCCESS);
  }

  task void writeToSDCardTask()
  {
    uint8_t ret;
    
    ret = writeBlock(m_cache.address, m_cache.block);

    printf("%s: %d\n\r", __FUNCTION__, ret);
    printfflush();
  }

  async command error_t SDCard.write(uint32_t addr, uint8_t *buf, uint16_t count) 
  {
    uint16_t inBlock = addr & BLOCK_MASK;
    uint16_t length = ( (inBlock + count) > BLOCK_SIZE) ? (BLOCK_SIZE - inBlock) : count;

    if (sdState == SD_IDLE)
    {    
      uint32_t blockAddress = addr & ~BLOCK_MASK;

      m_writeAddr = addr;
      m_writeBuf = buf;
      m_writeLen = length;

      if (m_cache.address == blockAddress)
      {
        // write directly to cache
        sdState = SD_WRITE_WRITE_TO_CACHE;
        post writeToCacheTask();
      }
      else
      {
        // read block to cache before write
        m_readAddr = blockAddress;
        m_readBuf = m_cache.block;
        m_readLen = BLOCK_SIZE;

        if (m_cache.dirty == FALSE)
        {
          // cache consistent, no need to flush cache        
          sdState = SD_WRITE_UPDATE_CACHE;
          post readFromSDCardTask();         
        }
        else
        {
          // flush cache to card first
          sdState = SD_WRITE_FLUSH_CACHE_BEFORE_READ;
          post writeToSDCardTask();
        }
      }

      printf("%s: %lX, %d\n\r", __FUNCTION__, addr, length);
      printfflush();
      
      return SUCCESS;
    }
    
    return FAIL;    
  }

  command uint32_t SDCard.readCardSize()
  { 
//    if (sdState == SD_IDLE)
//      return readCardSize();
      
    return 0;
  }

  async command error_t SDCard.clearSectors(uint32_t offset, uint16_t nbSectors)
  {
    if (sdState == SD_IDLE)
    {    
      m_sectorStart = offset & ~BLOCK_MASK;
      m_sectorEnd = m_sectorStart + 512 * (nbSectors - 1);
      
      if ( (m_sectorStart <= m_cache.address) && (m_cache.address <= m_sectorEnd) )
      {
        m_cache.address = INVALID_ADDRESS;
        m_cache.dirty = FALSE;
      }
      
      printf("%s: %lX, %lX, %lX\n\r", __FUNCTION__, m_cache.address, m_sectorStart, m_sectorEnd);
      printfflush();
      
      sdState = SD_ERASE;
      post clearSectorsTask();
      
      return SUCCESS;
    }
    
    return FAIL;
  }
  
  task void clearSectorsTask()
  {
    eraseSectors(m_sectorStart, m_sectorEnd);
  }
  


  /***************************************************************************/
  /***************************************************************************/
  /***************************************************************************/

  // send command to MMC
  uint16_t mmcSendCmd(uint8_t cmd, uint32_t data, uint8_t crc)
  {
    uint8_t i, extra;
    uint16_t Rx;
    uint8_t frame[6];

    // format command
    frame[0] = (cmd | 0x40);    
    frame[1] = (uint8_t) (data >> 24);
    frame[2] = (uint8_t) (data >> 16);
    frame[3] = (uint8_t) (data >> 8);
    frame[4] = (uint8_t) data;    
    frame[5] = crc;

    // transmit over SPI bus
    for(i = 0; i < 6; i++)
      call SpiByte.write(frame[i]);

    // read response, wait at most 8 bytes (req. by standard)
    i = 8;
    do 
    {
      Rx = call SpiByte.write(DUMMY_CHAR);
    } 
    while ( (Rx == 0xFF) && (i-- > 0) );
    
    // try one more byte to see if R2
    extra = call SpiByte.write(DUMMY_CHAR);
    
    if (extra != 0xFF)
      Rx = (Rx << 8) | extra;

    return Rx;
  }




  // Check if MMC card is still busy
  void mmcCheckBusy(void)
  {
    uint8_t response;
    uint16_t now;
    uint16_t start = call PowerTimeout.getNow();

    // a write should take at most 250 ms according to the standard
    do
    {
      response = call SpiByte.write(DUMMY_CHAR);
      now = call PowerTimeout.getNow();
    }
    while ( (response == MMC_BUSY) && ((now - start) < 250) );

  }


  uint8_t mmcSetBlockLength(const uint16_t blocklength)
  {
    uint8_t R1;
    
    // Set the block length. Write lengths MUST be 512 by standard
    R1 = mmcSendCmd(MMC_SET_BLOCKLEN, blocklength, 0xFF);

    // get response from MMC - make sure that its 0x00 (R1 ok response format)
    if(R1 != MMC_SUCCESS)
      return MMC_BLOCK_SET_ERROR;

    return MMC_SUCCESS;
  } // Set block_length




  /***************************************************************************/
  /***************************************************************************/
  /***************************************************************************/

  // Initialize MMC card
  uint8_t reset(void)
  {
    uint8_t i;
    uint8_t R1;

    // undocumented send 8 bytes
    for (i = 0; i < 8; i++)
      call SpiByte.write(DUMMY_CHAR);

    // select SD card
    call Select.clr();

    //Send CMD0 to reset and put MMC in SPI mode
    R1 = mmcSendCmd(MMC_GO_IDLE_STATE, 0, 0x95);

    if(R1 != R1_IN_IDLE_STATE)
      return MMC_INIT_ERROR;

    do
    {
      // send CMD1 until IDLE flag is cleared
      R1 = mmcSendCmd(MMC_SEND_OP_COND, 0, 0xff);
    }
    while(R1 == R1_IN_IDLE_STATE);

    call Select.set();

    // send 8 cycles to let the SD card finish (req. by standard)
    call SpiByte.write(DUMMY_CHAR);

    return MMC_SUCCESS;
  }


  uint8_t eraseSectors(uint32_t sectorStart, uint32_t sectorEnd)
  {
    uint8_t R1;
    
    call Select.clr();

    mmcSendCmd(MMC_TAG_SECTOR_START, sectorStart, 0xff);
    mmcSendCmd(MMC_TAG_SECTOR_END, sectorEnd, 0xff);
    mmcSendCmd(MMC_EREASE, 0, 0xff);

    mmcCheckBusy();

    call Select.set();

    // send 8 cycles to let the SD card finish (req. by standard)
    call SpiByte.write(0xff);
    sdState = SD_IDLE;

    return MMC_SUCCESS;
  } 


  // read a size Byte big block beginning at the address.
  uint8_t readBlock(const uint32_t address, const uint16_t count, uint8_t *pBuffer)
  {
    uint8_t R1;
    uint8_t ret = MMC_RESPONSE_ERROR;

    // CS = LOW (on)
    call Select.clr();

    // Set the block length to read
    if (mmcSetBlockLength(count) == MMC_SUCCESS)   
    {
      // block length could be set

      // send read command MMC_READ_SINGLE_BLOCK=CMD17
      R1 = mmcSendCmd(MMC_READ_SINGLE_BLOCK, address, 0xFF);

      // Check if the MMC acknowledged the read block command
      // it will do this by sending an affirmative response
      // in the R1 format (0x00 is no errors)
      if (R1 == MMC_R1_RESPONSE)
      {
        uint16_t now;
        uint16_t start = call PowerTimeout.getNow();

        // now look for the data token to signify the start of the data
        // This takes at most 100 ms (req. by standard)
        do
        {
          R1 = call SpiByte.write(DUMMY_CHAR);
          now = call PowerTimeout.getNow();
        }
        while ( (R1 != MMC_START_DATA_BLOCK_TOKEN) && ((now - start) < 100) );


        // check if timeout
        if (R1 == MMC_START_DATA_BLOCK_TOKEN)
        {
          // receive bytes
          // continues in sendDone
          ret = call SpiPacket.send(NULL, pBuffer, count);
        }
        else
        {
          // token never received, clean up
          call Select.set();
          call SpiByte.write(DUMMY_CHAR);

          ret = MMC_DATA_TOKEN_ERROR;      // 3
        }
      }
      else
      {
        // the MMC never acknowledge the read command, clean up 
        call Select.set();
        call SpiByte.write(DUMMY_CHAR);

        ret = MMC_RESPONSE_ERROR;          // 2
      }
    }
    else
    {
      // invalid block set, clean up
      call Select.set();
      call SpiByte.write(DUMMY_CHAR);

      ret = MMC_BLOCK_SET_ERROR;           // 1
    }

    return ret;
  }  



  uint8_t writeBlock(const uint32_t address, uint8_t *pBuffer)
  {
    uint8_t R1;
    uint8_t ret = MMC_RESPONSE_ERROR;

    call Select.clr();

    // set write block length to 512 (req. by standard)
    if (mmcSetBlockLength(512) == MMC_SUCCESS)   
    {
      // block length could be set

      // send write command
      R1 = mmcSendCmd(MMC_WRITE_BLOCK, address, 0xFF);

      // check if the MMC acknowledged the write block command
      // it will do this by sending an affirmative response
      // in the R1 format (0x00 is no errors)
      if (R1 == MMC_R1_RESPONSE)
      {
        // timing byte (Nwr in standard)
        call SpiByte.write(DUMMY_CHAR);

        // send the data token to signify the start of the data
        call SpiByte.write(MMC_START_DATA_BLOCK_WRITE);

        // clock the actual data transfer and transmitt the bytes
        ret = call SpiPacket.send(pBuffer, NULL, 512);

        // continues in sendDone
      }
      else
      {
        // the MMC never acknowledge the write command

        // give the MMC the required clocks to finish up 
        call Select.set();
        call SpiByte.write(DUMMY_CHAR);

        ret = MMC_RESPONSE_ERROR;   // 2
      }
    }
    else
    {    
      // give the MMC the required clocks to finish up 
      call Select.set();
      call SpiByte.write(DUMMY_CHAR);

      ret = MMC_BLOCK_SET_ERROR;   // 1
    }

    return ret;
  } 

/*
  // mmc Get Responce
  uint8_t mmcGetResponse(void)
  {
    //Response comes 1-8bytes after command
    //the first bit will be a 0
    //followed by an error code
    //data will be 0xff until response
    uint8_t i = 0;

    uint8_t response;

    while( i <= 64)
    {
      response = call SpiByte.write(DUMMY_CHAR);
      
      if(response == 0x00)
        break;
        
      if(response == 0x01)
        break;
 
      i++;
    }
    
    return response;
  }

  uint8_t mmcGetXXResponse(const uint8_t resp)
  {
    //Response comes 1-8bytes after command
    //the first bit will be a 0
    //followed by an error code
    //data will be 0xff until response
    uint16_t i = 0;

    uint8_t response;

    while( i <= 10000)
    {
      response = call SpiByte.write(DUMMY_CHAR);
      if (response == resp)
        break;
      i++;
    }
    return response;
  }


  // Read the Card Size from the CSD Register
  uint32_t readCardSize(void)
  {
    // Read contents of Card Specific Data (CSD)  
    uint32_t MMC_CardSize;
    uint16_t i,      // index
             j,      // index
             b,      // temporary variable
             response,   // MMC response to command
             mmc_C_SIZE;

    uint8_t mmc_READ_BL_LEN,  // Read block length
            mmc_C_SIZE_MULT;

    call Select.clr();
    
    call SpiByte.write(MMC_READ_CSD);   // CMD 9

    for (i = 4; i > 0 ; i--)      // Send four dummy bytes
      call SpiByte.write(0x00);
      
    call SpiByte.write(DUMMY_CHAR);   // Send CRC byte

    response = mmcGetResponse();

    // data transmission always starts with 0xFE
    b = call SpiByte.write(DUMMY_CHAR);

    if( !response )
    {
      while (b != 0xFE) 
        b = call SpiByte.write(DUMMY_CHAR);

      // bits 127:87
      for( j = 5; j > 0; j--)          // Host must keep the clock running for at
        b = call SpiByte.write(DUMMY_CHAR);

      // 4 bits of READ_BL_LEN
      // bits 84:80
      b = call SpiByte.write(DUMMY_CHAR);  // lower 4 bits of CCC and
      mmc_READ_BL_LEN = b & 0x0F;
      b = call SpiByte.write(DUMMY_CHAR);

      // bits 73:62  C_Size
      // xxCC CCCC CCCC CC
      mmc_C_SIZE = (b & 0x03) << 10;
      b = call SpiByte.write(DUMMY_CHAR);
      mmc_C_SIZE += b << 2;
      b = call SpiByte.write(DUMMY_CHAR);
      mmc_C_SIZE += b >> 6;

      // bits 55:53
      b = call SpiByte.write(DUMMY_CHAR);
      // bits 49:47
      mmc_C_SIZE_MULT = (b & 0x03) << 1;
      b = call SpiByte.write(DUMMY_CHAR);
      mmc_C_SIZE_MULT += b >> 7;
      // bits 41:37
      b = call SpiByte.write(DUMMY_CHAR);
      b = call SpiByte.write(DUMMY_CHAR);
      b = call SpiByte.write(DUMMY_CHAR);
      b = call SpiByte.write(DUMMY_CHAR);
      b = call SpiByte.write(DUMMY_CHAR);
    }

    for( j = 4; j > 0; j--)          // Host must keep the clock running for at
      b = call SpiByte.write(DUMMY_CHAR);  // least Ncr (max = 4 bytes) cycles after
                               // the card response is received
    b = call SpiByte.write(DUMMY_CHAR);

    call Select.clr();


    MMC_CardSize = (mmc_C_SIZE + 1);
    // power function with base 2 is better with a loop
    // i = (pow(2,mmc_C_SIZE_MULT+2)+0.5);
    for (i = 2, j = mmc_C_SIZE_MULT + 2; j > 1; j--)
      i <<= 1;

    MMC_CardSize *= i;

    // power function with base 2 is better with a loop
    //i = (pow(2,mmc_READ_BL_LEN)+0.5);
    for (i = 2, j = mmc_READ_BL_LEN; j > 1; j--)
      i <<= 1;
    MMC_CardSize *= i;

    return MMC_CardSize;
  }
  






  // Reading the contents of the CSD and CID registers in SPI mode is a simple
  // read-block transaction.
  uint8_t readRegister(const uint8_t cmd_register, const uint16_t length, uint8_t *pBuffer)
  {
    uint8_t uc = 0;
    uint8_t rvalue = MMC_TIMEOUT_ERROR;

    if (setBlockLength(length) == MMC_SUCCESS)
    {
      call Select.clr();
      
      // CRC not used: 0xff as last byte
      mmcSendCmd(cmd_register, 0x000000, 0xff);

      // wait for response
      // in the R1 format (0x00 is no errors)
      if (mmcGetResponse() == 0x00)
      {
        if (mmcGetXXResponse(0xfe) == 0xfe)
          for (uc = 0; uc < length; uc++)
            pBuffer[uc] = call SpiByte.write(DUMMY_CHAR);  //mmc_buffer[uc] = spiSendByte(0xff);
        // get CRC bytes (not really needed by us, but required by MMC)
        call SpiByte.write(DUMMY_CHAR);
        call SpiByte.write(DUMMY_CHAR);
        rvalue = MMC_SUCCESS;
      }
      else
        rvalue = MMC_RESPONSE_ERROR;
      // CS = HIGH (off)
      call Select.set();

      // Send 8 Clock pulses of delay.
      call SpiByte.write(DUMMY_CHAR);
    }

    return rvalue;
  } // mmc_read_register
*/
}

