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
  uses interface Timer<TMilli> as PowerTimer;
  uses interface Timer<TMilli> as ResetTimer;
  uses interface Timer<TMilli> as BusyTimer;
}

implementation {

#define MINIMUM_READ_LENGTH (4)
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

#define TIMER_RESET_RETRY_MS  (100)
#define TIMER_BUSY_RETRY_MS   (25)

	enum {
      SD_NOINIT = 0,
      SD_IDLE = 1,
      SD_POWER_DOWN,
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

  uint32_t readCardSize(void);
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

  norace uint32_t m_bypassAddr;
  norace uint16_t m_bypassLen;
  norace uint8_t m_bypassCache[4];
  norace uint8_t *m_bypassPtr;
  
  norace uint32_t m_sectorStart;
  norace uint32_t m_sectorEnd;

  bool powerTimeoutRunning = FALSE;

  task void eraseSectorsTask();
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
        
    return SUCCESS;
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
  
  task void stopPowerTimeoutTask(){
    call PowerTimeout.stop();
  }

  void stopPowerTimeout(){
    atomic{
      powerTimeoutRunning = FALSE;
      post stopPowerTimeoutTask();
    }
  }

  async command error_t Resource.immediateRequest() 
  {
    error_t error = FAIL;
    
//    call CardDetect.setResistor(MSP430_PORT_RESISTOR_PULLUP);

//    if(call CardDetect.get())
//    {
      error = call SpiResource.immediateRequest();

      if (error == SUCCESS)
        call PowerTimer.stop();
//    }
//    else
//      error = FAIL;
      
//    call CardDetect.setResistor(MSP430_PORT_RESISTOR_OFF);

    return error;
  }

  async command error_t Resource.release() 
  {        
    return call SpiResource.release();
  }

  async command bool Resource.isOwner() {
    return call SpiResource.isOwner();
  }


  event void SpiResource.granted()
  { 
    if (sdState == SD_NOINIT)
    {
      sdState = SD_IDLE;
      call SDCard.powerUp();
      
      reset(); 
    } 
    else
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

                    sdState = SD_IDLE;

                    // the read length has been padded
                    if (m_bypassLen < MINIMUM_READ_LENGTH)
                    {
                      uint8_t in, out;

                      // check if read address has been boundary adjusted
                      if (m_bypassAddr != INVALID_ADDRESS)
                        out = m_bypassAddr - m_readAddr;
                      else
                        out = 0;

                      // copy data local from cache to client buffer
                      for ( in = 0 ; (in < m_bypassLen) && (out < MINIMUM_READ_LENGTH) ; in++, out++ )
                      {
                        m_bypassPtr[in] = m_rxBuf[out];
                      }

                      signal SDCard.readDone(m_bypassAddr, m_bypassPtr, m_bypassLen, m_error);
                    }
                    else
                      signal SDCard.readDone(m_readAddr, m_rxBuf, m_len, m_error);

                    break;

      case SD_WRITE_UPDATE_CACHE:

                    call Select.set();

                    // give the MMC the required clocks to finish up 
                    call SpiByte.write(DUMMY_CHAR);

                    // update cache address, m_readAddr is the block address
                    m_cache.address = m_readAddr;
                    // m_cache.dirty = FALSE; // redundant, we are modifying the cache immediately

                    // read block from SD card to cache
                    // continue write operation by copying write buffer to cache
                    sdState = SD_WRITE_WRITE_TO_CACHE;
                    post writeToCacheTask();
                    break;                    

      case SD_WRITE_FLUSH_CACHE_BEFORE_READ:

                    // write's status response      
                    call SpiByte.write(DUMMY_CHAR);

                    // wait until the SD card is finished writing
                    mmcCheckBusy();

                    break;
                    
      case SD_WRITE_FLUSH_CACHE:

                    // write's status response      
                    call SpiByte.write(DUMMY_CHAR);

                    // wait until the SD card is finished writing
                    mmcCheckBusy();

                    break;
      
      default:
                    break;
    }

  }

  /***************************************************************************/
  /* SDCard                                                                    */
  /***************************************************************************/
  task void startPowerTimeoutTask(){
    call PowerTimeout.startOneShot(10);
  }

  void startPowerTimeout(){
    powerTimeoutRunning = TRUE;
    post startPowerTimeoutTask();
  }

  event void PowerTimer.fired()
  {
    if (sdState == SD_POWER_DOWN)
    {
      sdState = SD_NOINIT;
      call Power.clr();
    }
  }


  command error_t SDCard.powerDown() 
  {
    if (sdState == SD_IDLE)
    {
      call PowerTimer.startOneShot(10);
      sdState = SD_POWER_DOWN;
    }
    
    return SUCCESS;
  }

  command error_t SDCard.powerUp() 
  {
    call PowerTimer.stop();
    call Power.set();

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
    readBlock(m_readAddr, m_readLen, m_readBuf);
  }

  command error_t SDCard.read(uint32_t addr, uint8_t *buf, uint16_t count) 
  {

    if (sdState == SD_IDLE)
    {    
      uint16_t inBlock = addr & BLOCK_MASK;
      uint16_t length = ( (inBlock + count) > BLOCK_SIZE) ? (BLOCK_SIZE - inBlock) : count;
      uint32_t blockAddress = addr & ~BLOCK_MASK;

      m_readAddr = addr;
      m_readLen = length;
      m_readBuf = buf;

      if (m_cache.address == blockAddress)
      {
        sdState = SD_READ_FROM_CACHE;
        post readFromCacheTask();
      }
      else
      {
        m_bypassAddr = INVALID_ADDRESS;
        m_bypassLen = m_readLen;

        // SDcard has a miminum read length
        if (m_bypassLen < MINIMUM_READ_LENGTH)
        {
          // save original buffer
          m_bypassPtr = m_readBuf;

          // use bypass variables
          m_readBuf = m_bypassCache;
          m_readLen = MINIMUM_READ_LENGTH;
          
          // and reads cannot cross blocks
          if ( (inBlock + MINIMUM_READ_LENGTH) > BLOCK_SIZE)
          {
            m_bypassAddr = m_readAddr;
            m_readAddr = blockAddress + BLOCK_SIZE - MINIMUM_READ_LENGTH;
          }
        }
        
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
    writeBlock(m_cache.address, m_cache.block);
  }

  command error_t SDCard.write(uint32_t addr, uint8_t *buf, uint16_t count) 
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
      
      return SUCCESS;
    }
    
    return FAIL;    
  }

  command uint32_t SDCard.readCardSize()
  { 
    if (sdState == SD_IDLE)
      return readCardSize();
      
    return 0;
  }

  command error_t SDCard.eraseSectors(uint32_t offset, uint16_t nbSectors)
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
            
      sdState = SD_ERASE;
      post eraseSectorsTask();
      
      return SUCCESS;
    }
    
    return FAIL;
  }
  
  task void eraseSectorsTask()
  {
    eraseSectors(m_sectorStart, m_sectorEnd);
  }
  

  command error_t SDCard.flush()
  {
    if (sdState == SD_IDLE)
    {    
      sdState = SD_WRITE_FLUSH_CACHE;
      post writeToSDCardTask();

      return SUCCESS;
    }
    
    return FAIL;
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
    i = 64; //8;
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



    uint16_t m_now;
    uint16_t m_start;

  // Check if MMC card is still busy
  void mmcCheckBusy(void)
  {
    uint8_t response;
    
    m_start = call PowerTimer.getNow();

    response = call SpiByte.write(DUMMY_CHAR);
    
    if (response == MMC_BUSY)
      call BusyTimer.startOneShot(TIMER_BUSY_RETRY_MS);
  }

  event void BusyTimer.fired()
  {
    uint8_t response;

    if (sdState == SD_IDLE)
      return;
    
    // a write should take at most 250 ms according to the standard
    m_now = call PowerTimer.getNow();

    response = call SpiByte.write(DUMMY_CHAR);

    if ((response != MMC_BUSY) || ((m_now - m_start) > 250) )
    {
      call Select.set();

      // send 8 cycles to let the SD card finish (req. by standard)
      call SpiByte.write(0xff);


      switch(sdState)
      {

        case SD_WRITE_FLUSH_CACHE_BEFORE_READ:

                  sdState = SD_WRITE_UPDATE_CACHE;
                  post readFromSDCardTask();         
                  break;

        case SD_WRITE_FLUSH_CACHE:

                  sdState = SD_IDLE;
                  m_cache.dirty = FALSE;
                  signal SDCard.flushDone();
                  break;
      
        case SD_ERASE:
                  sdState = SD_IDLE;
                  signal SDCard.eraseSectorsDone();
                  break;
        default:
                break;
      }   
    }
    else
      call BusyTimer.startOneShot(TIMER_BUSY_RETRY_MS);      
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
    uint8_t R1;
    uint8_t i;

    // undocumented send 8 bytes
    for (i = 0; i < 8; i++)
      call SpiByte.write(DUMMY_CHAR);

    // select SD card
    call Select.clr();

    //Send CMD0 to reset MMC 
    R1 = mmcSendCmd(MMC_GO_IDLE_STATE, 0, 0x95);

    if(R1 != R1_IN_IDLE_STATE)
      return MMC_INIT_ERROR;

    // send CMD0 to enter SPI mode
    R1 = mmcSendCmd(MMC_SEND_OP_COND, 0, 0xff);

    // card init can take 300-400 ms
    call ResetTimer.startOneShot(TIMER_RESET_RETRY_MS);
    
    return MMC_SUCCESS;
  }    

  event void ResetTimer.fired()
  {   
    // send CMD1 and check if IDLE flag is cleared
    if (mmcSendCmd(MMC_SEND_OP_COND, 0, 0xff) != R1_IN_IDLE_STATE)
    {
      call Select.set();

      // send 8 cycles to let the SD card finish (req. by standard)
      call SpiByte.write(DUMMY_CHAR);
    
      signal Resource.granted();    
    }
    else
      call ResetTimer.startOneShot(TIMER_RESET_RETRY_MS);    
  }


  uint8_t eraseSectors(uint32_t sectorStart, uint32_t sectorEnd)
  {
    uint8_t i;
    
    // undocumented send 8 bytes
    for (i = 0; i < 8; i++)
      call SpiByte.write(DUMMY_CHAR);

    call Select.clr();

    mmcSendCmd(MMC_TAG_SECTOR_START, sectorStart, 0xff);
    mmcSendCmd(MMC_TAG_SECTOR_END, sectorEnd, 0xff);
    mmcSendCmd(MMC_ERASE, 0, 0xff);

    mmcCheckBusy();

    return MMC_SUCCESS;
  } 


  // read a size Byte big block beginning at the address.
  uint8_t readBlock(const uint32_t address, const uint16_t count, uint8_t *pBuffer)
  {
    uint8_t R1;
    uint8_t ret = MMC_RESPONSE_ERROR;
    uint8_t i;

    // undocumented send 8 bytes
    for (i = 0; i < 8; i++)
      call SpiByte.write(DUMMY_CHAR);

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
        uint16_t start = call PowerTimer.getNow();

        // now look for the data token to signify the start of the data
        // This takes at most 100 ms (req. by standard)
        do
        {
          R1 = call SpiByte.write(DUMMY_CHAR);
          now = call PowerTimer.getNow();
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
    uint8_t i;
    
    // undocumented send 8 bytes
    for (i = 0; i < 8; i++)
      call SpiByte.write(DUMMY_CHAR);

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

  // Read the Card Size from the CSD Register
  uint32_t readCardSize(void)
  {
    uint8_t R1;
    uint32_t cardSize = 0;
    uint8_t k;
    
    // undocumented send 8 bytes
    for (k = 0; k < 8; k++)
      call SpiByte.write(DUMMY_CHAR);

    call Select.clr();
    
    // send read CSD command 
    R1 = mmcSendCmd(MMC_READ_CSD, 0, 0xFF);

    // Check if the MMC acknowledged the read CSD command
    // it will do this by sending an affirmative response
    // in the R1 format (0x00 is no errors)
    if (R1 == MMC_R1_RESPONSE)
    {
      uint16_t now;
      uint16_t start = call PowerTimer.getNow();

      // now look for the data token to signify the start of the data
      // This takes at most 100 ms (req. by standard)
      do
      {
        R1 = call SpiByte.write(DUMMY_CHAR);
        now = call PowerTimer.getNow();
      }
      while ( (R1 != MMC_START_DATA_BLOCK_TOKEN) && ((now - start) < 100) );

      // got data block token
      if (R1 == MMC_START_DATA_BLOCK_TOKEN)
      {
        uint16_t i,j;
        uint8_t MMC_READ_BL_LEN;
        uint16_t MMC_C_SIZE;
        uint16_t MMC_C_SIZE_MULT;
        uint8_t MMC_SECTOR_SIZE;
        
        // the CSD register is 16 bytes wide. not all values are used.
        
        // ignore 5 first bytes of the CSD
        for (i = 0; i < 5; i++)
          call SpiByte.write(DUMMY_CHAR);

        // READ_BL_LEN [84:80]
        R1 = call SpiByte.write(DUMMY_CHAR); //  80 -  87
        MMC_READ_BL_LEN = R1 & 0x0F;

        // C_SIZE [73:62]
        R1 = call SpiByte.write(DUMMY_CHAR); //  72 -  79
        MMC_C_SIZE = (R1 & 0x03) << 10;
        R1 = call SpiByte.write(DUMMY_CHAR); //  64 -  71
        MMC_C_SIZE += R1 << 2;
        R1 = call SpiByte.write(DUMMY_CHAR); //  56 -  63
        MMC_C_SIZE += R1 >> 6;

        // C_SIZE_MULT [49:47]
        R1 = call SpiByte.write(DUMMY_CHAR); //  48 -  55
        MMC_C_SIZE_MULT = (R1 & 0x03) << 1;
        R1 = call SpiByte.write(DUMMY_CHAR); //  40 -  47
        MMC_C_SIZE_MULT += R1 >> 7;

        // SECTOR_SIZE [45:39] 
        MMC_SECTOR_SIZE = (R1 & 0x3F) << 1;
        R1 = call SpiByte.write(DUMMY_CHAR); //  32 -  39
        MMC_SECTOR_SIZE += R1 >> 7;

        // ignore last 4 bytes
        for (i = 0; i < 4; i++)
          call SpiByte.write(DUMMY_CHAR);


        // calculate card size
        cardSize = (MMC_C_SIZE + 1);
        // power function with base 2 is better with a loop
        // i = (pow(2,MMC_C_SIZE_MULT+2)+0.5);
        for (i = 2, j = MMC_C_SIZE_MULT + 2; j > 1; j--)
          i <<= 1;

        cardSize *= i;

        // power function with base 2 is better with a loop
        //i = (pow(2,mmc_READ_BL_LEN)+0.5);
        for (i = 2, j = MMC_READ_BL_LEN; j > 1; j--)
          i <<= 1;

        cardSize *= i;
      }

      call Select.set();
      call SpiByte.write(DUMMY_CHAR);
    }

    return cardSize;
  }
  
  default event void SDCard.flushDone() {};

}

