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
  provides {
    interface Resource;
    interface SDCard;
  }
	uses {
    interface Resource as SpiResource;
    interface SpiByte;
    interface SpiPacket;      
    interface GeneralIO as Select;

    interface GeneralIO as Power;
    interface HplMsp430GeneralIO as CardDetect;

    interface Leds;
    interface StdOut;
  }
}

implementation {
	enum {
      SD_NOINIT,
      SD_IDLE,
      SD_READ,
      SD_WRITE,
      SD_ERASE
  };

  void mmcSendCmd(const uint8_t cmd, uint32_t data, const uint8_t crc);
  uint8_t mmcGoIdle();
  uint8_t mmcGetResponse(void);
  uint8_t mmcGetXXResponse(const uint8_t resp);
  uint8_t mmcInit(void);
  uint8_t mmcCheckBusy(void);
  uint8_t mmcReadBlock(const uint32_t address, const uint16_t count, uint8_t *pBuffer);
  uint8_t mmcWriteBlock(const uint32_t address, const uint16_t count, uint8_t *pBuffer);
  uint32_t mmcReadCardSize(void);

  norace uint8_t sdState=SD_NOINIT;

  norace uint32_t m_addr;
  norace uint8_t* m_txBuf;
  norace uint8_t* m_rxBuf; 
  norace uint16_t m_len;
  norace error_t m_error;
  
  task void spiSendDoneTask();

  /***************************************************************************/
  /***************************************************************************/
  /***************************************************************************/

  async command error_t Resource.request() 
  {
    error_t error = FAIL;
    
    if (sdState == SD_NOINIT)
    {
      // call Power.set();
      // call Power.makeOutput();

      call Select.makeOutput();
      
      call CardDetect.makeInput();
      call CardDetect.setResistor(MSP430_PORT_RESISTOR_PULLUP);
    
      if(call CardDetect.get())
        error = call SpiResource.request();
      
      call CardDetect.setResistor(MSP430_PORT_RESISTOR_OFF);
    }

    return error;
  }

  async command error_t Resource.immediateRequest() 
  {
    error_t error = FAIL;
    
    if (sdState == SD_NOINIT)
    {
      // call Power.set();
      // call Power.makeOutput();

      call Select.makeOutput();
      
      call CardDetect.makeInput();
      call CardDetect.setResistor(MSP430_PORT_RESISTOR_PULLUP);
    
      if(call CardDetect.get())
        error = call SpiResource.immediateRequest();
      
      call CardDetect.setResistor(MSP430_PORT_RESISTOR_OFF);
    }

    return error;
  }

  async command error_t Resource.release() 
  {
    error_t error = FAIL;
    
    if (sdState == SD_IDLE)
    {
      // power down SD card 

      sdState = SD_NOINIT;
      error = call SpiResource.release();
    }
    
    // release SPI bus    
    return error;
  }

  async command bool Resource.isOwner() 
  {
    return call SpiResource.isOwner();
  }


  event void SpiResource.granted()
  { 
    mmcInit();
    
    signal Resource.granted();
  }

  /***************************************************************************/
  /***************************************************************************/
  /***************************************************************************/

  async event void SpiPacket.sendDone( uint8_t* txBuf, uint8_t* rxBuf, uint16_t len, error_t error)
  {
    m_txBuf = txBuf;
    m_rxBuf = txBuf;
    m_len = len;
    m_error = error;
    
    post spiSendDoneTask();
  }  


  task void spiSendDoneTask()  
  {
        
    switch(sdState)
    {
      case SD_WRITE:
                    // put CRC bytes (not really needed by us, but required by MMC)
                    call SpiByte.write(DUMMY_CHAR);
                    call SpiByte.write(DUMMY_CHAR);
                    // read the data response xxx0<status>1 : status 010: Data accected, status 101: Data
                    //   rejected due to a crc error, status 110: Data rejected due to a Write error.
                    mmcCheckBusy();

                    // give the MMC the required clocks to finish up what ever it needs to do
                    //  for (i = 0; i < 9; ++i)
                    //    spiSendByte(0xff);
                    call Select.set();
                    // Send 8 Clock pulses of delay.
                    call SpiByte.write(DUMMY_CHAR);

                    signal SDCard.writeDone(m_addr, m_txBuf, m_len, m_error);
                    break;
                    
      case SD_READ:                
                    // put CRC bytes (not really needed by us, but required by MMC)
                    call SpiByte.write(DUMMY_CHAR);
                    call SpiByte.write(DUMMY_CHAR);

                    // give the MMC the required clocks to finish up what ever it needs to do
                    //  for (i = 0; i < 9; ++i)
                    //    spiSendByte(0xff);
                    call Select.set();
                    // Send 8 Clock pulses of delay.
                    call SpiByte.write(DUMMY_CHAR);

                    signal SDCard.readDone(m_addr, m_rxBuf, m_len, m_error);
                    break;
      default:
                    break;
    }

    sdState = SD_IDLE;
  }

  /***************************************************************************/
  /* SDCard                                                                    */
  /***************************************************************************/

  command error_t SDCard.read(uint32_t addr, uint8_t *buf, uint16_t count) 
  {
    uint8_t ret;
    
    m_addr = addr;
    ret = mmcReadBlock(addr, count, buf);
    sdState = SD_READ;

    return ret;    
  }

  command error_t SDCard.write(uint32_t addr, uint8_t *buf, uint16_t count) 
  {
    uint8_t ret;
    
    m_addr = addr;
    ret = mmcWriteBlock(addr, count, buf);
    sdState = SD_WRITE;

    return ret;    
  }

  command uint32_t SDCard.readCardSize()
  {
    return mmcReadCardSize();
  }

  command uint8_t SDCard.checkBusy()
  {
    uint8_t ret;
    
    ret = mmcCheckBusy();
    
    return ret;
  }

  command error_t SDCard.clearSectors(uint32_t offset, uint16_t nbSectors){
        error_t error = FAIL;
        atomic {
          if (sdState != SD_IDLE) return FAIL;
      sdState = SD_WRITE;
    }
        call Select.clr();
        // Envoie de la demande d'infos
        mmcSendCmd(32/*0x60*/,offset,0xff);
        if (mmcGetXXResponse(0x00) != 0x00){ // Reponse
            goto end;    
        }
        call Select.set();
        call SpiByte.write(0xff);
        call Select.clr();
        mmcSendCmd(33,offset+512*(nbSectors-1),0xff);
        if (mmcGetXXResponse(0x00) != 0x00){ // Reponse
            goto end;    
        }
        call Select.set();
        call SpiByte.write(0xff);
        call Select.clr();
        mmcSendCmd(38,0,0xff);
        if (mmcGetXXResponse(0x00) != 0x00) {
            goto end;
        }
        call Select.set();
        call SpiByte.write(0xff);
        error =SUCCESS;
    
    end:
      atomic sdState = SD_IDLE;
        return error;
    } 


  /* incoming serial data */
  async event void StdOut.get(uint8_t data) 
  {
    ;
  }

  /***************************************************************************/
  /***************************************************************************/
  /***************************************************************************/

  // send command to MMC
  void mmcSendCmd(uint8_t cmd, uint32_t data, uint8_t crc)
  {
    uint8_t frame[6];
    int8_t i;

    frame[0] = (cmd | 0x40);
    
    for ( i = 3; i >= 0; i--)
      frame[4-i] = (uint8_t) (data >> (8 * i));
    
    frame[5] = crc;

    for(i = 0; i < 6; i++)
      call SpiByte.write(frame[i]);
  }

  // Initialize MMC card
  uint8_t mmcInit(void)
  {
    uint8_t i;
    //raise CS and MOSI for 80 clock cycles
    //SendByte(0xff) 10 times with CS high

    //RAISE CS
    // Init Port for MMC (default high)
    // Chip Select
    // Card Detect
    // Init SPI Module
    // Enable secondary function

    //initialization sequence on PowerUp
    call Select.set();

    for(i = 0; i <= 9; i++)
      call SpiByte.write(DUMMY_CHAR);

    return (mmcGoIdle());
  }

  // set MMC in Idle mode
  uint8_t mmcGoIdle()
  {
    uint8_t response = 0x01;
    call Select.clr();

    //Send Command 0 to put MMC in SPI mode
    mmcSendCmd(MMC_GO_IDLE_STATE,0,0x95);
    //Now wait for READY RESPONSE
    if(mmcGetResponse() != 0x01)
      return MMC_INIT_ERROR;

    while(response == 0x01)
    {
      call Select.set();
      call SpiByte.write(DUMMY_CHAR);
      call Select.clr();
      mmcSendCmd(MMC_SEND_OP_COND,0x00,0xff);
      response = mmcGetResponse();
    }
    call Select.set();
    call SpiByte.write(DUMMY_CHAR);

    return MMC_SUCCESS;
  }

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

    while( i <= 1000)
    {
      response = call SpiByte.write(DUMMY_CHAR);
      if (response == resp)
        break;
      i++;
    }
    return response;
  }


  // Check if MMC card is still busy
  // The card will respond with a standard response token followed by a data
  // block suffixed with a 16 bit CRC.
  uint8_t mmcCheckBusy(void)
  {
    //Response comes 1-8bytes after command
    //the first bit will be a 0
    //followed by an error code
    //data will be 0xff until response
    uint8_t i = 0;

    uint8_t response;
    uint8_t rvalue;

    while (i <= 64)
    {
      response = call SpiByte.write(DUMMY_CHAR);
      response &= 0x1f;

      switch(response)
      {
        case 0x05: rvalue=MMC_SUCCESS;break;
        case 0x0b: return(MMC_CRC_ERROR);
        case 0x0d: return(MMC_WRITE_ERROR);
        default:
          rvalue = MMC_OTHER_ERROR;
          break;
      }
      if(rvalue==MMC_SUCCESS)break;
      i++;
    }
    i=0;
    do
    {
      response = call SpiByte.write(DUMMY_CHAR);
      i++;
    } while(response==0);

    return response;
  }


  //--------------- set blocklength 2^n ------------------------------------------------------
  uint8_t mmcSetBlockLength(const uint16_t blocklength)
  {
    // CS = LOW (on)
    call Select.clr();

    // Set the block length to read
    mmcSendCmd(MMC_SET_BLOCKLEN, blocklength, 0xFF);

    // get response from MMC - make sure that its 0x00 (R1 ok response format)
    if(mmcGetResponse() != 0x00)
    { 
      mmcInit();
      mmcSendCmd(MMC_SET_BLOCKLEN, blocklength, 0xFF);
      mmcGetResponse();
    }

    call Select.set();

    // Send 8 Clock pulses of delay.
    call SpiByte.write(DUMMY_CHAR);

    return MMC_SUCCESS;
  } // Set block_length


  // Reading the contents of the CSD and CID registers in SPI mode is a simple
  // read-block transaction.
  uint8_t mmcReadRegister(const uint8_t cmd_register, const uint16_t length, uint8_t *pBuffer)
  {
    uint8_t uc = 0;
    uint8_t rvalue = MMC_TIMEOUT_ERROR;

    if (mmcSetBlockLength(length) == MMC_SUCCESS)
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
    call Select.set();
    return rvalue;
  } // mmc_read_register


  /***************************************************************************/
  /***************************************************************************/
  /***************************************************************************/

  // read a size Byte big block beginning at the address.
  uint8_t mmcReadBlock(const uint32_t address, const uint16_t count, uint8_t *pBuffer)
  {
    uint8_t rvalue = MMC_RESPONSE_ERROR;

    // Set the block length to read
    if (mmcSetBlockLength(count) == MMC_SUCCESS)   // block length could be set
    {
      // CS = LOW (on)
      call Select.clr();

      // send read command MMC_READ_SINGLE_BLOCK=CMD17
      mmcSendCmd(MMC_READ_SINGLE_BLOCK, address, 0xFF);

      // Send 8 Clock pulses of delay, check if the MMC acknowledged the read block command
      // it will do this by sending an affirmative response
      // in the R1 format (0x00 is no errors)
      if (mmcGetResponse() == 0x00)
      {
        // now look for the data token to signify the start of
        // the data
        if (mmcGetXXResponse(MMC_START_DATA_BLOCK_TOKEN) == MMC_START_DATA_BLOCK_TOKEN)
        {
          // clock the actual data transfer and receive the bytes; spi_read automatically finds the Data Block
          // spiReadFrame(pBuffer, count);
          rvalue = call SpiPacket.send(NULL, pBuffer, count);

          // get CRC bytes (not really needed by us, but required by MMC)
//          call SpiByte.write(DUMMY_CHAR);
//          call SpiByte.write(DUMMY_CHAR);
//          rvalue = MMC_SUCCESS;
        }
        else
        {
          call Select.set();
          call SpiByte.write(DUMMY_CHAR);

          // the data token was never received
          rvalue = MMC_DATA_TOKEN_ERROR;      // 3
        }
      }
      else
      {
        call Select.set();
        call SpiByte.write(DUMMY_CHAR);

        // the MMC never acknowledge the read command
        rvalue = MMC_RESPONSE_ERROR;          // 2
      }
    }
    else
    {
      rvalue = MMC_BLOCK_SET_ERROR;           // 1
    }

    return rvalue;
  }// mmc_read_block



  //char mmcWriteBlock (const unsigned long address)
  uint8_t mmcWriteBlock(const uint32_t address, const uint16_t count, uint8_t *pBuffer)
  {
    uint8_t rvalue = MMC_RESPONSE_ERROR;         // MMC_SUCCESS;
    //  char c = 0x00;

    // Set the block length to read
    if (mmcSetBlockLength(count) == MMC_SUCCESS)   // block length could be set
    {
      // CS = LOW (on)
      call Select.clr();
      // send write command
      mmcSendCmd (MMC_WRITE_BLOCK,address, 0xFF);

      // check if the MMC acknowledged the write block command
      // it will do this by sending an affirmative response
      // in the R1 format (0x00 is no errors)
      if (mmcGetXXResponse(MMC_R1_RESPONSE) == MMC_R1_RESPONSE)
      {
        call SpiByte.write(DUMMY_CHAR);
        // send the data token to signify the start of the data
        call SpiByte.write(0xfe);
        // clock the actual data transfer and transmitt the bytes

        // spiSendFrame(pBuffer, count);
        rvalue = call SpiPacket.send(pBuffer, NULL, count);

      }
      else
      {

        // give the MMC the required clocks to finish up what ever it needs to do
        //  for (i = 0; i < 9; ++i)
        //    spiSendByte(0xff);
        call Select.set();
        // Send 8 Clock pulses of delay.
        call SpiByte.write(DUMMY_CHAR);

        // the MMC never acknowledge the write command
        rvalue = MMC_RESPONSE_ERROR;   // 2
      }
    }
    else
    {
      rvalue = MMC_BLOCK_SET_ERROR;   // 1
    }

    return rvalue;
  } // mmc_write_block



  // Read the Card Size from the CSD Register
  uint32_t mmcReadCardSize(void)
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
  




}

