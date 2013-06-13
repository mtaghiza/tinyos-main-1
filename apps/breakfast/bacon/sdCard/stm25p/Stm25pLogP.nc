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
 * @version $Revision: 1.9 $ $Date: 2009-12-23 02:28:47 $
 */

#include <Stm25p.h>

module Stm25pLogP {
  
  provides interface Init;
  provides interface LogRead as Read[ uint8_t id ];
  provides interface LogWrite as Write[ uint8_t id ];
  
  uses interface Stm25pSector as Sector[ uint8_t id ];
  uses interface Resource as ClientResource[ uint8_t id ];
  uses interface Get<bool> as Circular[ uint8_t id ];
  provides interface Stm25pVolume as Volume[uint8_t id];
  uses interface Leds;

  //for informing other code when an append is completed (indicates
  //  how much data was appended)
  provides interface Notify<uint8_t>[uint8_t id];
}

implementation {

  stm25p_addr_t write_addrs[NUM_VOLUMES];

  #ifndef SINGLE_RECORD_READ
  #define SINGLE_RECORD_READ 0
  #endif

  #if SINGLE_RECORD_READ == 1
  #warning "Using single-record log read"
  #endif

  enum {
    NUM_LOGS = uniqueCount( "Stm25p.Log" ),
    BLOCK_SIZE = 2048,
    BLOCK_SIZE_LOG2 = 11,
    BLOCK_MASK = BLOCK_SIZE - 1,
    BLOCKS_PER_SECTOR = STM25P_SECTOR_SIZE / BLOCK_SIZE,
    MAX_RECORD_SIZE = 254,
    INVALID_HEADER = 0x00,
  };
  
  typedef enum {
    S_IDLE,
    S_READ,
    S_SEEK,
    S_ERASE,
    S_APPEND,
    S_SYNC,
  } stm25p_log_req_t;

  typedef struct stm25p_log_state_t {
    storage_cookie_t cookie;
    void* buf;
    uint8_t len;
    uint8_t m_len;
    bool m_records_lost;
    stm25p_log_req_t req;
  } stm25p_log_state_t;

  typedef struct stm25p_log_info_t {
    stm25p_addr_t read_addr;
    stm25p_addr_t remaining;
  } stm25p_log_info_t;
  
  stm25p_log_state_t m_log_state[ NUM_LOGS ];
  stm25p_log_state_t m_req;
  stm25p_log_info_t m_log_info[ NUM_LOGS ];
  stm25p_addr_t m_addr;
  uint8_t m_header;

  typedef enum {
    S_SEARCH_BLOCKS = 0,
    S_SEARCH_RECORDS = 1,
    S_SEARCH_SEEK = 2,
    S_HEADER = 3,
    S_DATA = 4,
  } stm25p_log_rw_state_t;

  stm25p_log_rw_state_t m_rw_state;

  error_t newRequest( uint8_t client );
  void continueReadOp( uint8_t client );
  void continueAppendOp( uint8_t client );
  void signalDone( uint8_t id, error_t error );
  
  command error_t Init.init() {
    int i;
    for ( i = 0; i < NUM_LOGS; i++ ) {
      stm25p_addr_t* write_addr = &write_addrs[signal Volume.getVolumeId[i]()];
      m_log_info[ i ].read_addr = STM25P_INIT_ADDRESS;


      // prevent log from starting at offset 0x00
      // since SD card use 0x00 for empty and not 0xff
      *write_addr = STM25P_SECTOR_SIZE;
    }
    return SUCCESS;
  }
  
  command error_t Read.read[ uint8_t id ]( void* buf, storage_len_t len ) {
    m_req.req = S_READ;
    m_req.buf = buf;
    m_req.len = len;
    m_req.m_len = len;
    
    return newRequest( id );
  }

  command error_t Read.seek[ uint8_t id ]( storage_addr_t cookie ) {
    stm25p_addr_t* write_addr = &write_addrs[signal Volume.getVolumeId[id]()];
    if ( cookie > *write_addr){
      return FAIL;
    }
    
    m_req.req = S_SEEK;
    m_req.cookie = cookie;
    return newRequest( id );
    
  }
  
  command storage_cookie_t Read.currentOffset[ uint8_t id ]() {
    return m_log_info[ id ].read_addr;
  }
  
  command storage_cookie_t Read.getSize[ uint8_t id ]() {
    return ( (storage_len_t)call Sector.getNumSectors[ id ]()
      << STM25P_SECTOR_SIZE_LOG2 );
  }
  
  command storage_cookie_t Write.currentOffset[ uint8_t id ]() {
    stm25p_addr_t* write_addr = &write_addrs[signal Volume.getVolumeId[id]()];
    return *write_addr;
  }
  
  command error_t Write.erase[ uint8_t id ]() {
    m_req.req = S_ERASE;
    return newRequest( id );
  }
  
  command error_t Write.append[ uint8_t id ]( void* buf, storage_len_t len ) {
    stm25p_addr_t* write_addr = &write_addrs[signal Volume.getVolumeId[id]()];
    uint16_t bytes_left = (uint16_t)(*write_addr) % BLOCK_SIZE;
    bytes_left = BLOCK_SIZE - bytes_left;
    
    // don't allow appends larger than maximum record size
    if ( len > MAX_RECORD_SIZE ){
      return EINVAL;
    }
    
    // move to next block if current block doesn't have enough space
    if ( sizeof( m_header ) + len > bytes_left ){
      *write_addr += bytes_left;
    }
    
    // if log is not circular, make sure it doesn't grow too large
    if ( !call Circular.get[ id ]() &&
       ( (uint8_t)(*write_addr >> STM25P_SECTOR_SIZE_LOG2) >=
         call Sector.getNumSectors[ id ]() ) ){
      return ESIZE;
    }
    
    m_req.m_records_lost = FALSE;
    m_req.req = S_APPEND;
    m_req.buf = buf;
    m_req.len = len;

    return newRequest( id );

  }
  
  command error_t Write.sync[ uint8_t id ]() {
    m_req.req = S_SYNC;
    return newRequest( id );
  }
  
  error_t newRequest( uint8_t client ) {
    
    if ( m_log_state[ client ].req != S_IDLE ){
      return FAIL;
    }
    
    call ClientResource.request[ client ]();
    m_log_state[ client ] = m_req;
    
    return SUCCESS;
    
  }
  
  uint8_t calcSector( uint8_t client, stm25p_addr_t addr ) {
    uint8_t sector = call Sector.getNumSectors[ client ]();
    return (uint8_t)(( addr >> STM25P_SECTOR_SIZE_LOG2 ) % sector);
  }

  stm25p_addr_t calcAddr( uint8_t client, stm25p_addr_t addr  ) {
    stm25p_addr_t result = calcSector( client, addr );
    result <<= STM25P_SECTOR_SIZE_LOG2;
    result |= addr & STM25P_SECTOR_MASK;
    return result;
  }

  event void ClientResource.granted[ uint8_t id ]() {

    // log never used, need to find start and end of log
    if ( m_log_info[ id ].read_addr == STM25P_INIT_ADDRESS &&
       m_log_state[ id ].req != S_ERASE ) {
      stm25p_addr_t* write_addr = &write_addrs[signal Volume.getVolumeId[id]()];
      //this could be improved slightly: a newly-initialized log
      //  client should always have to find start of log for read, but
      //  may not have to find end of log (if another client on the
      //  same volume has already done that search).
      //The search logic assumes that write_addr starts at 0, so we
      //  enforce that here. This will result in some duplicated
      //  effort, though it makes the logic simpler and reduces the
      //  amount of state that has to be tracked.


      // prevent log from starting at offset 0x00
      // since SD card use 0x00 for empty and not 0xff
      *write_addr = STM25P_SECTOR_SIZE;


      m_rw_state = S_SEARCH_BLOCKS;
      call Sector.read[ id ]( 0, (uint8_t*)&m_addr, sizeof( m_addr ) );
    } else {
    // start and end of log known, do the requested operation
      switch( m_log_state[ id ].req ) {
        case S_READ:
          //remaining=0: state is read_header. !=0 : read data
          m_rw_state = (m_log_info[ id ].remaining) ? S_DATA : S_HEADER;
          continueReadOp( id );
          break;
        case S_SEEK:
        {
          // make sure the cookie is still within the range of valid data
          stm25p_addr_t* write_addr = &write_addrs[signal Volume.getVolumeId[id]()];
          uint8_t numSectors = call Sector.getNumSectors[ id ]();
          uint8_t readSector = 
            (m_log_state[ id ].cookie >> STM25P_SECTOR_SIZE_LOG2);
          uint8_t writeSector =
            ((*write_addr-1)>>STM25P_SECTOR_SIZE_LOG2)+1;
          // if cookie is overwritten, advance to beginning of log
          if ( (writeSector - readSector) > numSectors ) {
            m_log_state[ id ].cookie = 
              (storage_cookie_t)(writeSector-numSectors)
              <<STM25P_SECTOR_SIZE_LOG2;
          }
          m_log_info[ id ].read_addr = m_log_state[ id ].cookie & ~BLOCK_MASK;
          m_log_info[ id ].remaining = 0;
          m_rw_state = S_SEARCH_SEEK;
          if (SINGLE_RECORD_READ){
            //advance to first record header on this block
            m_log_info[id].read_addr += sizeof(m_addr);
            //if we aren't there yet, then we need to read the first
            //record header and proceed from there.
            if ( m_log_info[ id ].read_addr < m_log_state[ id ].cookie ) {
              call Sector.read[ id ]( 
                calcAddr( id, m_log_info[ id ].read_addr ), 
                &m_header, sizeof( m_header ) );
            }else{
              signalDone( id, SUCCESS );
            }

          } else{
            if ( m_log_info[ id ].read_addr != m_log_state[ id ].cookie ) {
              m_log_info[ id ].read_addr += sizeof( m_addr );
              call Sector.read[ id ]( 
                calcAddr( id, m_log_info[ id ].read_addr ), 
                &m_header, sizeof( m_header ) );
            }else{
              signalDone( id, SUCCESS );
            }
          }
        }
        break;
      case S_ERASE:
        call Sector.erase[ id ]( 0, call Sector.getNumSectors[ id ]() );
        break;
      case S_APPEND:
        m_rw_state = S_HEADER;
        continueAppendOp( id );
        break;
      case S_SYNC:
        signalDone( id, SUCCESS );
        break;
      case S_IDLE:
        break;
      }
    }
  }

  void continueReadOp( uint8_t client ) {
    
    stm25p_addr_t read_addr = m_log_info[ client ].read_addr;
    stm25p_addr_t* write_addr = &write_addrs[signal Volume.getVolumeId[client]()];
    uint8_t* buf;
    uint8_t len;
    error_t error;

    uint8_t m_len = m_log_state[ client ].m_len;

    // if on block boundary
    //at block boundary: advance read_addr to first record start
    if ( !((uint16_t)read_addr & BLOCK_MASK ) ){
      read_addr += sizeof( m_addr );
    }

    // check if all done
    if ( m_len == 0 || read_addr >= *write_addr ) {
      signalDone( client, SUCCESS );
      return;
    }

    if ( m_rw_state == S_DATA ) {
      // if header is invalid, move to next block
      if ( m_header == INVALID_HEADER ) {
        m_rw_state = S_HEADER;
        read_addr += BLOCK_SIZE;
        read_addr &= ~BLOCK_MASK;
        buf = &m_header;
        len = sizeof( m_header );
      } else {
        if (SINGLE_RECORD_READ){
          if (m_log_info[client].remaining > m_log_state[client].len){
            //Not enough space for record, we're done.
            //Note that we explicitly check for this in
            //Sector.readDone and shouldn't reach this point. If we
            //have reached this point, read_addr is not pointing at a
            //record header. While this should still work OK, calling
            //currentOffset right now would give a result that is 1+
            //the correct/unambiguous cookie value. Since we require
            //that cookie 
            signalDone(client, FAIL);
            return;
          } else{
            //it fits, I sits.
            // m_len is the remaining data to read,
            // m_log_info[client].len is the filled part of the buffer
            len = m_log_info[client].remaining;
            //read into client buffer
            buf = m_log_state[client].buf;
          }
        }else{
          //read into &(buffer + requested len - read-so-far)
          buf = m_log_state[ client ].buf + m_log_state[ client ].len - m_len;
          // truncate if record is shorter than requested length
          if ( m_log_info[ client ].remaining < m_len ){
            len = m_log_info[ client ].remaining;
          }else{
            len = m_len;
          }
        }
      }
    }else{
      //S_HEADER behavior if not S_DATA.
      buf = &m_header;
      len = sizeof( m_header );
    }
    
    m_log_info[ client ].read_addr = read_addr;
    error = call Sector.read[ client ]( calcAddr( client, read_addr ), buf, len );
  }
  
  event void Sector.readDone[ uint8_t id ]( stm25p_addr_t addr, uint8_t* buf,
                                  stm25p_len_t len, error_t error ) {
 
    stm25p_log_info_t* log_info = &m_log_info[ id ];
    stm25p_addr_t *write_addr = &write_addrs[signal Volume.getVolumeId[id]()];

    uint8_t m_len = m_log_state[ id ].m_len;


    // searching for the first and last log blocks
    switch( m_rw_state ) {
      case S_SEARCH_BLOCKS: 
        {
          uint16_t block = addr >> BLOCK_SIZE_LOG2;
          // record potential starting and ending addresses
          if ( m_addr != STM25P_EMPTY_ADDRESS ) {
            if ( m_addr < log_info->read_addr ){
              log_info->read_addr = m_addr;
            }
            if ( m_addr > *write_addr ){
              *write_addr = m_addr;
            }
          }
          // move on to next log block (check header of block)
          if (++block < (call Sector.getNumSectors[ id ]()*BLOCKS_PER_SECTOR)) {
            addr += BLOCK_SIZE;
            call Sector.read[ id ]( addr, 
              (uint8_t*)&m_addr, 
              sizeof( m_addr ) );
          } else if ( log_info->read_addr == STM25P_INIT_ADDRESS ) {
            // if log is empty, continue operation

            // prevent log from starting at offset 0x00
            // since SD card use 0x00 for empty and not 0xff
            log_info->read_addr = STM25P_SECTOR_SIZE; 
            *write_addr = STM25P_SECTOR_SIZE;         


            signal ClientResource.granted[ id ]();
          } else {
          // search for last record
            *write_addr += sizeof( m_addr );
            m_rw_state = S_SEARCH_RECORDS;
            call Sector.read[ id ]( 
              calcAddr(id, *write_addr), 
              &m_header, 
              sizeof( m_header ) );
          }
        }
        break;
  
      case S_SEARCH_RECORDS: 
        {
          // searching for the last log record to write
          uint16_t cur_block = *write_addr >> BLOCK_SIZE_LOG2;
          uint16_t new_block = ( *write_addr + sizeof( m_header ) + m_header ) >> BLOCK_SIZE_LOG2;
          // if header is valid and is on same block, move to next record
          if ( m_header != INVALID_HEADER && cur_block == new_block ) {
            *write_addr += sizeof( m_header ) + m_header;
            call Sector.read[ id ]( 
              calcAddr( id, *write_addr ), 
              &m_header, 
              sizeof( m_header ) );
          } else {
          // found last record
            signal ClientResource.granted[ id ]();
          }
        }
        break;
  
      case S_SEARCH_SEEK:
        {
          // searching for last log record to read
          //stash log_info->read_addr before advancing
          storage_addr_t last_read_addr = log_info->read_addr;
          //advances read_addr to next record start 
          // (+=header len + header val)
          log_info->read_addr += sizeof( m_header ) + m_header;
          // if not yet at cookie, keep searching
          if ( log_info->read_addr < m_log_state[ id ].cookie ) {
            call Sector.read[ id ]( 
              calcAddr(id, log_info->read_addr), 
              &m_header, 
              sizeof( m_header ) );
          } else {
            // at or passed cookie, stop        
            if (SINGLE_RECORD_READ){
              //backtrack to start of record. remaining=0 means "this
              //pointing at a header"
              if ( log_info->read_addr > m_log_state[ id ].cookie ) {

                log_info->remaining = 0;
                log_info->read_addr = last_read_addr;
              }else{
                //cool. we hit it exactly.
                //if we are now pointing at a block header, advance
                //it to the next record header to disambiguate
                if ( (log_info->read_addr & BLOCK_MASK) < sizeof(m_addr)){
                  log_info->read_addr =
                    (log_info->read_addr & BLOCK_MASK) + sizeof(m_addr);
                }
              }
            } else{
              log_info->remaining = log_info->read_addr - m_log_state[ id ].cookie;
              log_info->read_addr = m_log_state[ id ].cookie;
            }
            signalDone( id, error );
          }
        }
        break;

      case S_HEADER:
        {
          // if header is invalid, move to next block
          if ( m_header == INVALID_HEADER ) {
            log_info->read_addr += BLOCK_SIZE;
            log_info->read_addr &= ~BLOCK_MASK;
          } else {
            //remaining = remaining in this record
            log_info->read_addr += sizeof( m_header );
            log_info->remaining = m_header;
            m_rw_state = S_DATA;
            if (SINGLE_RECORD_READ){
              //check for fit
              if (log_info->remaining > m_log_state[id].len){
                //doesn't fit: go back to header, signal done
                log_info->read_addr -= sizeof(m_header);
                log_info->remaining = 0;
                signalDone(id, ESIZE);
                return;
              }
            }
          }
          continueReadOp( id );
        }
        break;

      case S_DATA:
        {
          log_info->read_addr += len;
          log_info->remaining -= len;
          //m_len is the number of bytes requested but not yet read
          m_len -= len;

          m_log_state[ id ].m_len = m_len;
          
          if (SINGLE_RECORD_READ){
            //single-record read: stop here.
            signalDone(id, error);
          }else{
            m_rw_state = S_HEADER;
            continueReadOp( id );
          }
          break;
        }
    }
  }

  void continueAppendOp( uint8_t client ) {
    
    stm25p_addr_t* write_addr = &write_addrs[signal Volume.getVolumeId[client]()];
    void* buf;
    uint8_t len;
    //so if this is interrupted between the record-header being
    //written and the data being written, the data will be lost but
    //the log structure will remain intact.

    // Start of a new sector? Erase it then.
    if ( !(*write_addr & STM25P_SECTOR_MASK) ) {
      m_log_state[ client ].m_records_lost = TRUE;
      call Sector.erase[ client ]( calcSector( client, *write_addr ), 1 );
    } else {
      //start of new block? write write_addr
      if ( !(*write_addr & BLOCK_MASK) ) {
        buf = write_addr;
        len = sizeof( m_addr );
      } else if ( m_rw_state == S_HEADER ) {
        //need to write header (len)? do so.
        buf = &m_log_state[ client ].len;
        len = sizeof( m_log_state[ client ].len );
      } else {
        //write actual data
        buf = m_log_state[ client ].buf;
        len = m_log_state[ client ].len;
      }
      call Sector.write[ client ]( calcAddr( client, *write_addr ), buf, len );
    }
  }

  event void Sector.eraseDone[ uint8_t id ]( uint8_t sector, 
                                   uint8_t num_sectors,
                                   error_t error ) {
    stm25p_addr_t* write_addr = &write_addrs[signal Volume.getVolumeId[id]()];
    if ( m_log_state[ id ].req == S_ERASE ) {

      // prevent log from starting at offset 0x00
      // since SD card use 0x00 for empty and not 0xff
      m_log_info[ id ].read_addr = STM25P_SECTOR_SIZE;
      *write_addr = STM25P_SECTOR_SIZE;

      signalDone( id, error );
    } else {
      // advance read pointer if write pointer has gone too far ahead
      // (the log could have cycled around)
      stm25p_addr_t volume_size = 
      STM25P_SECTOR_SIZE * ( call Sector.getNumSectors[ id ]() - 1 );
      if ( *write_addr > volume_size ) {
      stm25p_addr_t read_addr = *write_addr - volume_size;
      if ( m_log_info[ id ].read_addr < read_addr )
        m_log_info[ id ].read_addr = read_addr;
      }
      m_addr = *write_addr;
      call Sector.write[ id ]( calcAddr( id, m_addr ), (uint8_t*)&m_addr, 
                        sizeof( m_addr ) );
    }
  }

  event void Sector.writeDone[ uint8_t id ]( storage_addr_t addr, 
                                   uint8_t* buf, 
                                   storage_len_t len, 
                                   error_t error ) {
    //unclear how this ensures writes don't span block boundaries.
    //maybe that's done by Sector?
    stm25p_addr_t* write_addr = &write_addrs[signal Volume.getVolumeId[id]()];
    *write_addr += len;
    if ( m_rw_state == S_HEADER ) {
      if ( len == sizeof( m_header ) ){
        m_rw_state = S_DATA;
      }
      continueAppendOp( id );
    } else {
      signalDone( id, error );
    }
  }
  
  void signalDone( uint8_t id, error_t error ) {
    
    stm25p_log_req_t req = m_log_state[ id ].req;
    void* buf = m_log_state[ id ].buf;
    storage_len_t len = m_log_state[ id ].len;

    uint8_t m_len = m_log_state[ id ].m_len;
    bool m_records_lost = m_log_state[ id ].m_records_lost;

    call ClientResource.release[ id ]();
    m_log_state[ id ].req = S_IDLE;
    switch( req ) {
      case S_IDLE:
        break;
      case S_READ:
        signal Read.readDone[ id ]( buf, len - m_len, error );
        break;
      case S_SEEK:
        signal Read.seekDone[ id ]( error );
        break;
      case S_ERASE:
        signal Write.eraseDone[ id ]( error );
        break;
      case S_APPEND:
        signal Notify.notify[id](len);
        signal Write.appendDone[ id ]( buf, len, m_records_lost, error );
        break;
      case S_SYNC:
        signal Write.syncDone[ id ]( error );
        break;
    }

//    printf("LogP: %08lX %08lX\n\r", m_log_info[ id ].read_addr, write_addrs[signal Volume.getVolumeId[ id ]()]);
//    printfflush();

  }

  event void Sector.computeCrcDone[ uint8_t id ]( stm25p_addr_t addr, stm25p_len_t len, uint16_t crc, error_t error ) {}
  
  default event void Read.readDone[ uint8_t id ]( void* data, storage_len_t len, error_t error ) {}
  default event void Read.seekDone[ uint8_t id ]( error_t error ) {}
  default event void Write.eraseDone[ uint8_t id ]( error_t error ) {}
  default event void Write.appendDone[ uint8_t id ]( void* data, storage_len_t len, bool recordsLost, error_t error ) {}
  default event void Write.syncDone[ uint8_t id ]( error_t error ) {}

  default command storage_addr_t Sector.getPhysicalAddress[ uint8_t id ]( storage_addr_t addr ) { return 0xffffffff; }
  default command uint8_t Sector.getNumSectors[ uint8_t id ]() { return 0; }
  default command error_t Sector.read[ uint8_t id ]( storage_addr_t addr, uint8_t* buf, storage_len_t len ) { return FAIL; }
  default command error_t Sector.write[ uint8_t id ]( storage_addr_t addr, uint8_t* buf, storage_len_t len ) { return FAIL; }
  default command error_t Sector.erase[ uint8_t id ]( uint8_t sector, uint8_t num_sectors ) { return FAIL; }
  default command error_t Sector.computeCrc[ uint8_t id ]( uint16_t crc, storage_addr_t addr, storage_len_t len ) { return FAIL; }
  default async command error_t ClientResource.request[ uint8_t id ]() { return FAIL; }
  default async command error_t ClientResource.release[ uint8_t id ]() { return FAIL; }
  default command bool Circular.get[ uint8_t id ]() { return FALSE; }
  
  default async event volume_id_t Volume.getVolumeId[uint8_t id](){
    return 0xFF;
  }

  default event void Notify.notify[uint8_t id](uint8_t val){}
  command error_t Notify.enable[uint8_t id](){ return SUCCESS;}
  command error_t Notify.disable[uint8_t id](){ return FAIL;}
}
