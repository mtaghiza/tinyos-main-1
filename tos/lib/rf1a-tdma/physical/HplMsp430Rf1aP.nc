/* Copyright (c) 2010 People Power Co.
 * All rights reserved.
 *
 * This open source code was developed with funding from People Power Company
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
 * - Neither the name of the People Power Corporation nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE
 * PEOPLE POWER CO. OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE
 *
 */

#include "Rf1aPacket.h"
#include "CXTDMADebug.h"
#include "BreakfastDebug.h"
#include "CXTDMADispatchDebug.h"
#include "FECDebug.h"
/** Implement the physical layer of the radio stack.
 *
 * This module follows TEP108-style resource management.  Each client
 * of the radio is entitled to use a different configuration
 * (including frequencies and data rates), and to manage the
 * higher-level packet content.  Hooks are added so that message
 * payload can be dynamically created on transmission, and stored in
 * arbitrary locations on reception.  There is no interface limit on
 * the physical message size, though the current implementation
 * supports only packets no more than 255 octets.
 *
 * Several assumptions are made about the radio configuration.
 * Signals are configured for specific FIFO status,
 * transmission/reception events, and signal state.  Radio state
 * transition is fixed: if no client is active, the radio is reset
 * (SLEEP); if a client is active but has no receive buffer prepared
 * it is IDLE; if a receive buffer is available it is RX.  The
 * CCA_MODE and TX-if-CCA features are enabled, but can be bypassed if
 * necessary through judicious use of the Rf1aPhysical methods.  */
generic module HplMsp430Rf1aP () @safe() {
  provides {
    interface ResourceConfigure[uint8_t client];
    interface Rf1aPhysical[uint8_t client];
    interface Rf1aStatus;
    interface Rf1aPhysicalMetadata;
    interface Rf1aCoreInterrupt[uint8_t client];
  }
  uses {
    interface ArbiterInfo;
    interface Rf1aFifo;
    interface HplMsp430Rf1aIf as Rf1aIf;
    interface Rf1aConfigure[uint8_t client];
    interface Rf1aTransmitFragment[uint8_t client];
    interface Rf1aInterrupts[uint8_t client];
    interface Leds;
  }
} implementation {
  int rssiConvert_dBm(uint8_t rssi_dec_);
  void sniffPacket(uint8_t* pkt, uint8_t received, uint8_t rssi,
      uint8_t lqi);

  /* See configure_ for details. on how these signals are used. */
  enum {
    // IFG4 positive to detect RX data available
    IFG_rxFifoAboveThreshold = (1 << 4),
    // IFG5 negative to detect RX data available
    IFG_txFifoAboveThreshold = (1 << 5),
    // IFG7 positive to detect RX FIFO overflow
    IFG_rxOverflow = (1 << 7), // positive
    // IFG8 positive to detect TX FIFO underflow
    IFG_txUnderflow = (1 << 8),
    // IFG9 positive to detect sync word
    IFG_syncWordEvent = (1 << 9),
    // IFG12 positive to perform clear channel assessment
    IFG_clearChannel = (1 << 12),
    // IFG13 positive to detect signal presence
    IFG_carrierSense = (1 << 13),
    IFG_INTERRUPT = IFG_rxFifoAboveThreshold 
      //| IFG_txFifoAboveThreshold
      | IFG_rxOverflow | IFG_txUnderflow
      | IFG_syncWordEvent
      | IFG_clearChannel | IFG_carrierSense,
    IFG_EDGE_Negative = IFG_txFifoAboveThreshold,
    IFG_EDGE_Positive = IFG_rxFifoAboveThreshold
      | IFG_rxOverflow | IFG_txUnderflow
      | IFG_syncWordEvent
      | IFG_clearChannel | IFG_carrierSense,
  };

  enum {
    /** Limit on iterations for loops awaiting a particular radio
     * state.  This is used to avoid an unbreakable loop when the
     * radio spontaneously enters IDLE mode, or fails to complete a
     * requested transition in an unanticipated way.  The number is
     * rather arbitrary, and is based on experience showing a maximum
     * of perhaps 1200 iterations before success in the normal
     * situation for at least one such loop.  It should not be too
     * large, to prevent long hangs.  It's somewhat safe to make it
     * "too small", since it should be used in situations where the
     * failure is propagated to allow the upper layers to retry the
     * operation. */
    RADIO_LOOP_LIMIT = 2000,
  };

  /** Constants defining the main radio control state machine state.
   * This is a high-resolution insight into what's going on, provided
   * by the MARCSTATE register.  It must be consulted sometimes to
   * work around radio bugs. */
  enum {
    MRCSM_SLEEP = 0,             // SLEEP substate of SLEEP
    MRCSM_IDLE = 1,              // IDLE substate of IDLE
    MRCSM_XOFF = 2,              // XOFF substate of XOFF
    MRCSM_VCOON_MC = 3,          // VCOON_MC substate of MANCAL,
    MRCSM_REGON_MC = 4,          // REGON_MC substate of MANCAL
    MRCSM_MANCAL = 5,            // MANCAL substate of MANCAL
    MRCSM_VCOON = 6,             // VCOON substate of FS_WAKEUP
    MRCSM_REGON = 7,             // REGON substate of FS_WAKEUP,
    MRCSM_STARTCAL = 8,          // STARTCAL substate of CALIBRATE
    MRCSM_BWBOOST = 9,           // BWBOOST substate of SETTLING
    MRCSM_FS_LOCK = 10,          // FS_LOCK substate of SETTLING
    MRCSM_IFADCON = 11,          // IFADCON substate of SETTLING,
    MRCSM_ENDCAL = 12,           // ENDCAL substate of CALIBRATE
    MRCSM_RX = 13,               // RX substate of RX
    MRCSM_RX_END = 14,           // RX_END substate of RX
    MRCSM_RX_RST = 15,           // RX_RST substate of RX,
    MRCSM_TXRX_SWITCH = 16,      // TXRX_SWITCH substate of TXRX_SETTLING
    MRCSM_RXFIFO_OVERFLOW = 17,  // RXFIFO_OVERFLOW substate of RXFIFO_OVERFLOW
    MRCSM_FSTXON = 18,           // FSTXON substate of FSTXON
    MRCSM_TX = 19,               // TX substate of TX,
    MRCSM_TX_END = 20,           // TX_END substate of TX
    MRCSM_RXTX_SWITCH = 21,      // RXTX_SWITCH substate of RXTX_SETTLING
    MRCSM_TXFIFO_UNDERFLOW = 22, // TXFIFO_UNDERFLOW substate of TXFIFO_UNDERFLOW
  };

  /* Reception state transitions.  The state is inactive when there is
   * no receive buffer and the API has not been used to force entry to
   * reception mode anyway: when the state is inactive, the radio will
   * not be in receive mode.  When the radio is in receive mode and is
   * not transmitting, it is in listening mode.  Upon receipt of data
   * beginning a message, it transitions to active, where it remains
   * until cancelled or the complete message has been received, at
   * which point it returns to inactive of listening depending on
   * availability of receive buffer space. */
  enum {
    /** Disabled when there is no receive buffer and no message
     * actively being received. */
    RX_S_inactive = 0x00,
    /** Waiting for start of a new message.  This is not an active
     * state, as there is no commitment to do anything yet.  */
    RX_S_listening = 0x01,
    /** The first data associated with an incoming message has been
     * received.  At this point we assume there is an active
     * reception.  However, the task that manages the reception has
     * not yet been queued. */
    RX_S_synchronized = 0x02,
    /** Actively receiving a message. */
    RX_S_active = 0x03,
  };
  /** Current state of the reception automaton. */
  uint8_t rx_state;
  /** Where the next data should be written.  Null if there is no
   * available reception buffer.  Set to null in receiveData_ when
   * last byte filled; set to non-null in setReceiveBuffer(). */
  uint8_t* rx_pos;

  /** End of the available receive buffer. */
  uint8_t* rx_pos_end;

  /** Where in the current receive buffer data from the currently
   * received message begins.  Null when buffer has been filled. */
  uint8_t* rx_start;

  /** TRUE iff only a single message should be stored in the given
   * buffer. */
  bool rx_single_use = TRUE;

  /** Number of bytes expected for the current message.  Valid only
   * when actively receiving a message. */
  unsigned int rx_expected;

  /** Number of bytes received so far in the current message.  Valid
   * only when actively receiving a message. */
  unsigned int rx_received;

  /** The success/failure result of the current reception.  Will be
   * SUCCESS unless something bad happens (reception cancelled or RX
   * overflow) */
  int rx_result;

  /** The RSSI provided via APPEND_STATUS at the last successful
   * receive.  This is the raw value provided by APPEND_STATUS, not
   * the dBm one. */
  uint8_t rx_rssi_raw;

  /** The LQI+CRC provided via APPEND_STATUS at the last successful
   * receive */
  uint8_t rx_lqi_raw;

  /* Transmission state transitions.  When no send is in progress, the
   * state is inactive.  Upon validation of a send request, the state
   * moves to preparing, and the sendFragment_() code is queued to
   * run.  Within sendFragment_(), as soon as message data has become
   * available, as much available data as fits is placed into the
   * transmit fifo, the STX strobe is executed, and the state
   * transitions to active.  As soon as the last octet of the message
   * has been queued, the state transitions to flushing, and the
   * FIFOTHR is reprogrammed to detect when the queue empties.  Once
   * the last byte has been transmitted, the state returns to inactive
   * and the sendDone event is signaled.
   *
   * Be aware that the radio will spontaneously transition out of
   * FSTXON if TX-if-CCA is enabled.  There is evidence as well that
   * this can also happen after a successful transition to TX.  Code
   * processing transmissions must be prepared to find itself with a
   * radio that is no longer in transmit mode, and to cancel the
   * transmission accordingly.
   *
   * Also note: Explicit invocations of startTransmission, e.g. for
   * preamble signalling or jamming, are not reflected in tx_state. */
  enum {
    /** No transmission active */
    TX_S_inactive,
    /** A transmission has been queued, but data has not yet been
     * supplied and the radio is still in FSTXON.  This is an active
     * state. */
    TX_S_preparing,
    TX_S_loaded,
    /** A transmission is active.  This is an active state. */
    TX_S_active,
    /** All data has been queued for transmission, but has not yet
     * left the TXFIFO.  This is an active state. */
    TX_S_flushing,
  };

  /** Current state of the transmission automaton */
  uint8_t tx_state;

  /** The success or failure value for the current transmission */
  int tx_result;

  /** Pointer to the current position within a send()-provided
   * outgoing message.  Null if no active transmission or the sender
   * did not provide a buffer (is doing gather transmission).  Used by
   * the default TransmitFragment implementation. */
  uint8_t* tx_pos;

  /** The end of the send()-provided outgoing message.  Used by the
   * default TransmitFragment implementation. */
  uint8_t* tx_end;

  /** The number of octets remaining to be transmitted.  This is the
   * value provided through the send() method, and does not include
   * octets introduced at this layer such as the length when using
   * variable packet length. */
  unsigned int tx_remain;

  enum {
    /** Maximum number of bytes we can put in the TX FIFO */
    FIFO_FILL_LIMIT = 63,
  };

  /** Cached value of FIFOTHR, overwritten during TX_S_flushing to
   * detect completion of transmission.  Only valid during
   * TX_S_flushing; must be rewritten to FIFOTHR if that state is
   * left. */
  uint8_t tx_cached_fifothr;

  /** Place the radio back into whatever state it belongs in when not
   * actively transmitting or receiving.  This is either RX or IDLE.
   * This method is capable of rousing the radio from sleep mode, as
   * well as simply returning it from some other active mode.  It is
   * not responsible for dealing with errors like RX or TX FIFO
   * over/underflows.
   *
   * @param rx_if_enabled If TRUE, will transition to RX if
   * appropriate.  If FALSE, will only transition to IDLE. */
  void resumeIdleMode_ (bool rx_if_enabled)
  {
    atomic {
      uint8_t strobe = RF_SIDLE;
      uint8_t state = RF1A_S_IDLE;
      uint8_t rc;
      HPL_ATOMIC_SET_PIN;
      /* Maybe wake radio from deep sleep */
      rc = call Rf1aIf.strobe(RF_SNOP);
      if (0x80 & rc) {
        while (0x80 & rc) {
          atomic rc = call Rf1aIf.strobe(RF_SIDLE);
        }
        while (RF1A_S_IDLE != (RF1A_S_MASK & rc)) {
          rc = call Rf1aIf.strobe(RF_SNOP);
        }
      }
      if (rx_if_enabled && (!! rx_pos)) {
        strobe = RF_SRX;
        state = RF1A_S_RX;
      }
      (void)call Rf1aIf.strobe(strobe);
      do {
        rc = call Rf1aIf.strobe(RF_SNOP);
      } while (state != (RF1A_S_MASK & rc));
      HPL_ATOMIC_CLEAR_PIN;
    }
  }

  /** Return TRUE iff transitioning the radio to a new state will not
   * corrupt an in-progress transmission. */
  bool transmitIsInactive_atomic_ ()
  {
    return (TX_S_inactive == tx_state) && (0 == call Rf1aIf.readRegister(TXBYTES));
  }

  /** Configure the radio for a specific client.  This includes
   * client-specific registers and the overrides necessary to ensure
   * the physical-layer assumptions are maintained. */
  void configure_ (const rf1a_config_t* config)
  {
    atomic {
      const uint8_t* cp = (const uint8_t*)config;
      HPL_ATOMIC_SET_PIN;

      /* Reset the core.  Should be unnecessary, but a BOR might leave
       * the radio with garbage in its TXFIFO, which won't get cleared
       * with a standard wake. */
      call Rf1aIf.resetRadioCore();

      /* Wake the radio into idle mode */
      resumeIdleMode_(FALSE);

      /* Write the basic configuration registers.  PATABLE first, so
       * that the subsequent non-PATABLE instruction resets the table
       * index. */
      call Rf1aIf.writeBurstRegister(PATABLE, config->patable, sizeof(config->patable));

      call Rf1aIf.writeBurstRegister(0, cp, RF1A_CONFIG_BURST_WRITE_LENGTH);

      call Rf1aIf.writeRegister(CHANNR, signal Rf1aPhysical.getChannelToUse[call ArbiterInfo.userId()]());
      /* Regardless of the configuration, the core functionality here
       * requires that the interrupts be configured a certain way.
       * IFG signals 4, 5, 7, 8, 9, and 12 are all used.  All but 5
       * are positive edge.  All but 12 are interrupt enabled.  Clear
       * the interrupt vector then configure these interrupts. */
      call Rf1aIf.setIfg(0);
      call Rf1aIf.setIes(IFG_EDGE_Negative | ((~ IFG_EDGE_Positive) & call Rf1aIf.getIes()));
      call Rf1aIf.setIe(IFG_INTERRUPT | call Rf1aIf.getIe());

      /* Again regardless of configuration, the control flow in this
       * module assumes that the radio returns to IDLE mode after
       * receiving a packet, and IDLE mode after transmitting a
       * packet.  The presence of a receive buffer, and whether that
       * buffer is marked for single-use, affects subsequent
       * configuration of this register. */
      call Rf1aIf.writeRegister(MCSM1, (0xf0 & call Rf1aIf.readRegister(MCSM1)));
      /* Reset all the packet the packet-related pointers and counters */
      rx_state = RX_S_inactive;
      rx_pos = rx_pos_end = rx_start = 0;
      rx_expected = rx_received = 0;
      tx_state = TX_S_inactive;
      tx_pos = tx_end = 0;
      tx_remain = 0;
      rx_result = tx_result = SUCCESS;

      //if we are not using one of the auto-cal settings, then
      //  we need to do a manual calibration here.
      if ( 0x00 == ((config->mcsm0 >> 4) & 0x03)){
        uint8_t rc;
        rc = call Rf1aIf.strobe(RF_SCAL);
        while (RF1A_S_IDLE != (RF1A_S_MASK & rc)) {
          rc = call Rf1aIf.strobe(RF_SNOP);
        }
      }
      HPL_ATOMIC_CLEAR_PIN;
    }
  }

  async command void Rf1aPhysical.readConfiguration[uint8_t client] (rf1a_config_t* config)
  {
    /* NB: We intentionally ignore the client here. */
    memset(config, 0, sizeof(config));
    atomic {
      HPL_ATOMIC_SET_PIN;
      call Rf1aIf.readBurstRegister(PATABLE, config->patable, sizeof(config->patable));
      call Rf1aIf.readBurstRegister(0, (uint8_t*)config, RF1A_CONFIG_BURST_READ_LENGTH);
      config->partnum = call Rf1aIf.readRegister(PARTNUM);
      config->version = call Rf1aIf.readRegister(VERSION);
      HPL_ATOMIC_CLEAR_PIN;
    }
  }

  /** Unconfigure.  Disable all interrupts and reset the radio core. */
  void unconfigure_ ()
  {
    atomic {
      HPL_ATOMIC_SET_PIN;
      call Rf1aIf.setIe((~ IFG_INTERRUPT) & call Rf1aIf.getIe());
      call Rf1aIf.resetRadioCore();
      HPL_ATOMIC_CLEAR_PIN;
    }
  }

  default async command const rf1a_config_t*
  Rf1aConfigure.getConfiguration[uint8_t client] ()
  {
    return &rf1a_default_config;
  }

  default async command void Rf1aConfigure.preConfigure[ uint8_t client ] () { }
  default async command void Rf1aConfigure.postConfigure[ uint8_t client ] () { }
  default async command void Rf1aConfigure.preUnconfigure[ uint8_t client ] () { }
  default async command void Rf1aConfigure.postUnconfigure[ uint8_t client ] () { }

  async command void ResourceConfigure.configure[uint8_t client] ()
  {
    const rf1a_config_t* cp = call Rf1aConfigure.getConfiguration[client]();
    if (0 == cp) {
      cp = &rf1a_default_config;
    }
    call Rf1aConfigure.preConfigure[client]();
    configure_(cp);
    call Rf1aConfigure.postConfigure[client]();
  }

  async command void ResourceConfigure.unconfigure[uint8_t client] ()
  {
    call Rf1aConfigure.preUnconfigure[client]();
    unconfigure_();
    call Rf1aConfigure.postUnconfigure[client]();
    signal Rf1aPhysical.released[client]();
  }
  
  /* @TODO@ Prevent release of resource when transmission in progress */

  /** Default implementation of transmitReadyCount_ just returns a
   * value based on the number of bytes left in the buffer provided
   * through send. */
  unsigned int transmitReadyCount_ (uint8_t client,
                                    unsigned int count)
  {
    unsigned int rv = count;
    atomic {
      HPL_ATOMIC_SET_PIN;
      if (tx_pos) {
        unsigned int remaining = (tx_end - tx_pos);
        if (remaining < rv) {
          rv = remaining;
        }
      } else {
        rv = 0;
      }
      HPL_ATOMIC_CLEAR_PIN;
    }
    return rv;
  }

  /** Default implementation of transmitData_ just returns a pointer
   * to a region of the buffer provided through send. */
  uint8_t* transmitData_ (uint8_t client,
                          unsigned int count)
  {
    uint8_t* rp;

    atomic {
      HPL_ATOMIC_SET_PIN;
      rp = tx_pos;
      if (rp) {
        unsigned int remaining = (tx_end - tx_pos);
        if (remaining >= count) {
          /* Have enough to handle the request.  Increment the position for
           * a following transfer; if this will be the last transfer, mark
           * it complete by zeroing the position pointer. */
          tx_pos += count;
          if (tx_pos == tx_end) {
            tx_pos = 0;
          }
        } else {
          /* Being asked for more than is available, which is an interface
           * violation, which aborts the transfer. */
          rp = tx_pos = 0;
        }
      }
      HPL_ATOMIC_CLEAR_PIN;
    }
    return rp;
  }

  // Forward declaration
  void sendFragment_ ();

  // Forward declaration
  void receiveData_ ();
  
  /** Task used to do the work of transmitting a fragment of a message. */
//  task void sendFragment_task () { 
//    #ifdef DEBUG_TX_P
//    printf("sf_t\n\r");
//    #endif
//    sendFragment_(); 
//  }
//
  /** Task used to do the work of consuming a fragment of a message. */
  task void receiveData_task () { receiveData_(); }

  /** Clear the transmission fifo.  The radio is left in idle mode. */
  void resetAndFlushTxFifo_ ()
  {
    uint8_t rc;
    
    /* Reset the radio: return to IDLE mode, then flush the TX buffer.
     * Radio should end in IDLE mode. */
    rc = call Rf1aIf.strobe(RF_SIDLE);
    while (RF1A_S_IDLE != (RF1A_S_MASK & rc)) {
      rc = call Rf1aIf.strobe(RF_SNOP);
    }
    rc = call Rf1aIf.strobe(RF_SFTX);
    while (RF1A_S_IDLE != (RF1A_S_MASK & rc)) {
      rc = call Rf1aIf.strobe(RF_SNOP);
    }
    resumeIdleMode_(TRUE);
  }

  /** Reset the radio and update state so the inner code of
   * sendFragment_ will abort the transmission.  This method should
   * only be called from within sendFragment_. */
  void cancelTransmit_ ()
  {
    /* Clearing the remainder count and updating the state to "active"
     * will cause the epilog of the sendFragment_ code to clean up the
     * transmission. */
    tx_remain = 0;
    tx_state = TX_S_active;

    resetAndFlushTxFifo_();
  }
 
  /** Invoke this to ensure the radio has been in RX mode long enough
   * to generate a valid RSSI measurement.
   *
   * The return value allows the caller to determine whether the radio
   * is still in RX mode; if not, RSSI/CCA/CarrierSense are not
   * guaranteed to be accurate.
   *
   * @return the latest radio status byte. */
  uint8_t spinForValidRssi__ ()
  {
    uint8_t rc;
    uint8_t mcsm1 = call Rf1aIf.readRegister(MCSM1);

    /* Delay until we're sure the RSSI measurement is valid.
     *
     * Trick: The clearChannel signal says RSSI is below threshold;
     * when CCA_MODE is set to generate a valid CCA the carrierSense
     * signal says that it's above threshold.  When one of those
     * signals is asserted, RSSI is valid.  Note that we do not touch
     * MCSM1.RX_OFF, lest doing so cause the RF1A state to stay in RX
     * after a reception when it should instead have gone to IDLE.
     *
     * If MCSM1.RX_OFF is 0 (e.g., single-use buffers) and the
     * radio is actively receiving a packet, we might end up in
     * IDLE mode before the RSSI check passes.  In that case, or
     * if anything else kicks us out of RX, break out and let
     * the state machine recover normally. */
    call Rf1aIf.writeRegister(MCSM1, 0x10 | (0x0f & mcsm1));
    do {
      rc = call Rf1aIf.strobe(RF_SNOP);
    } while ((RF1A_S_RX == (RF1A_S_MASK & rc))
             && (! ((IFG_clearChannel | IFG_carrierSense) & call Rf1aIf.getIn())));

    // Restore standard CCA configuration
    call Rf1aIf.writeRegister(MCSM1, mcsm1);
    return rc;
  }

  norace uint8_t tx_client;


  /** Activity invoked to request data from the client and stuff it
   * into the transmission fifo. */
  void loadFifo_(uint8_t* buffer, uint8_t dataLength){
    bool need_to_write_length = FALSE;
    const uint8_t* data;
    unsigned int count;
    unsigned int inuse;
    TXCP_SET_PIN;
    //save tx info
    atomic {
      HPL_ATOMIC_SET_PIN;
      tx_remain = dataLength;
      tx_result = SUCCESS;
      tx_state = TX_S_preparing;
      if (buffer) {
        tx_pos = buffer;
        tx_end = buffer + dataLength;
      } else {
        tx_pos = tx_end = 0;
      }
      tx_client = call ArbiterInfo.userId();
      HPL_ATOMIC_CLEAR_PIN;
    }
    inuse = call Rf1aIf.readRegister(TXBYTES);
    /* If we're using variable packet lengths, and we haven't
     * written anything yet, we've got to reserve room for (and
     * send) the length byte. */
    need_to_write_length = (TX_S_preparing == tx_state) && (0x01 == (0x03 & call Rf1aIf.readRegister(PKTCTRL0)));

    /* Calculate the headroom, adjust for the length byte if we
     * need to write it, and adjust down to no more than we
     * need */
    count = FIFO_FILL_LIMIT - inuse;
    if (need_to_write_length) {
      count -= 1;
    }
    if (count > tx_remain) {
      count = tx_remain;
    }

    /* Is there any data ready?  If not, try again later. */
    count = call Rf1aTransmitFragment.transmitReadyCount[tx_client](count);
    if (0 == count) {
      return;
    }

    /* Get the data to be written.  If the callee returns a null
     * pointer, the transmission is canceled; otherwise, stuff it
     * into the transmit buffer. */
    data = call Rf1aTransmitFragment.transmitData[tx_client](count);
    if (0 == data) {
      cancelTransmit_();
      return;
    }

    /* We're committed to the write: tell the radio how long the
     * packet is, if we haven't already. */
    #ifdef DEBUG_TX_P
    printf("WTX: %d + %d\n\r", sizeof(uint8_t), count);
    #endif
    //disable TXFIFO interrupt: only using it to wait for packet
    //to clear.
    call Rf1aIf.setIe( 
      call Rf1aIf.getIe() & ~IFG_txFifoAboveThreshold);
    if (need_to_write_length) {
      uint8_t len8 = call Rf1aFifo.getEncodedLen(tx_remain) 
        + call Rf1aFifo.getCrcLen();
//      printf_FEC("Len %u + %u\r\n", 
//        call Rf1aFifo.getEncodedLen(tx_remain),
//        call Rf1aFifo.getCrcLen());
      //FEC not encoded: should reflect encoded length
      call Rf1aFifo.writeTXFIFO(&len8, sizeof(len8), TRUE);
    }
    TXCP_CLEAR_PIN;
    //TODO: signal up to PartialSend.getWriteLength(): default wiring
    //      should indicate entire packet. If we are non-origin,
    //      indicate entire packet.
    //TODO: fill in buffer with PartialSend.getWriteLength() bytes.
    //TODO: if data remains, save state and yield by signalling
    //      PartialSend.writePaused()
    //TODO: upper layer will get TX capture, fill in timestamp, and
    //      then call PartialSend.completeWrite(), continues with the
    //      rest of the packet.

    //FEC: encode this data on the way in.
    call Rf1aFifo.writeTXFIFO (data, count, FALSE);
    tx_state = TX_S_loaded;
    /* Account for what we just queued. */
    tx_remain -= count;
    if (tx_remain != 0){
      #ifdef DEBUG_TX_P
      printf("Trouble: %d bytes remain\n\r", tx_remain);
      #endif
    }  
  }


  uint8_t* tx_buffer;
  uint8_t tx_length;

  async command error_t Rf1aPhysical.completeSend[uint8_t clientId](){
    /* Radio must be assigned */
    if (! call ArbiterInfo.inUse()) {
      return EOFF;
    }
    if(clientId != call ArbiterInfo.userId()){
      //the wrong client tried to complete a send. shouldn't happen.
      return EBUSY;
    }  
    atomic{
      /* If we've queued data but haven't already started the
       * transmission, do so now. */
      //DC: this should always hold, could remove it.
//      if ((RF1A_S_TX != (RF1A_S_MASK & call Rf1aIf.strobe(RF_SNOP)))) {
        register int loop_limit = RADIO_LOOP_LIMIT;
        uint8_t rc;
        HPL_ATOMIC_SET_PIN;
        /* We're *supposed* to be in FSTXON here, so this strobe can't
         * be rejected.  In fact, it appears that if we're in FSTXON
         * and CCA fails, the radio transitions to RX mode.  In other
         * cases, it somehow ends up in IDLE.  Try anyway, and if it
         * doesn't work, fail the transmission. */
        //4.25 uS
        TX_TOGGLE_PIN;
        TXCP_CLEAR_PIN;
        FS_STROBE_CLEAR_PIN;
        STROBE_SET_PIN;
        rc = call Rf1aIf.strobe(RF_STX);
        STROBE_CLEAR_PIN;
        TXCP_SET_PIN;
        //5.75 uS
        TX_TOGGLE_PIN;
        GETPACKET_SET_PIN;
        //packet retrieval/validation: cancel the transmission if we
        //the client doesn't provide a packet or if the length is
        //valid 
        if( ! signal Rf1aPhysical.getPacket[clientId](&tx_buffer, &tx_length) 
           || 0 == tx_length || tx_length >= FIFO_FILL_LIMIT){
          resumeIdleMode_(FALSE);
          HPL_ATOMIC_CLEAR_PIN;
          return ESIZE;
        }
        GETPACKET_CLEAR_PIN;
        //2.25 uS
        TX_TOGGLE_PIN;
        //TODO: would be cool to put timestamp in at the right point.
        // how to do this? getPacket should return the packet, total
        // length, and an optional pause index. When loadfifo hits the
        // pause index, it stops.
        // at synchCapture.captured, we set the timestamp and then hit
        // unpause, which lets loadFifo finish..
        LOADFIFO_SET_PIN;
        loadFifo_(tx_buffer, tx_length);
        LOADFIFO_CLEAR_PIN;
        //48.5 uS
        TX_TOGGLE_PIN;
        while ((RF1A_S_TX != (RF1A_S_MASK & rc))
               && (RF1A_S_RX != (RF1A_S_MASK & rc))
               && (RF1A_S_IDLE != (RF1A_S_MASK & rc))
               && (0 <= --loop_limit)) {
          rc = call Rf1aIf.strobe(RF_SNOP);
        }
        //7.5 uS
        TX_TOGGLE_PIN;
        tx_state = TX_S_active;

        //call IndicatorPin.clr();
        if (RF1A_S_TX != (RF1A_S_MASK & rc)) {
          tx_result = ERETRY;
          cancelTransmit_();
          HPL_ATOMIC_CLEAR_PIN;
          return tx_result;
        }
//      }
      /* If we've started transmitting, see if we're done yet. */
      if (TX_S_active <= tx_state) {
        /* If there's no more data to be transmitted, the task is
         * done.  However, there's an end-game: we don't really want
         * to signal sendDone until it's actually in the air.  */
        if (0 == tx_remain) {
          if (TX_S_active == tx_state) {
            tx_state = TX_S_flushing;
            tx_cached_fifothr = call Rf1aIf.readRegister(FIFOTHR);
            call Rf1aIf.writeRegister(FIFOTHR, (0x0F | tx_cached_fifothr));
            //set up FIFOTHR register and enable FE interrupt so we
            //get interrupted when the last byte is out of the FIFO
            call Rf1aIf.setIe(call Rf1aIf.getIe() |
              IFG_txFifoAboveThreshold);
          }
        }
      }
      HPL_ATOMIC_CLEAR_PIN;
    } // atomic
    //all of the above code paths will result in a sendDone,
    //eventually.
    return SUCCESS;
  }

  

  /** Place the radio into FSTXON or TX, with or without a
   * clear-channel-assessment gate check.
   *
   * @param with_cca If TRUE, radio should check for a clear channel
   * before proceeding with the transition.  If false, use only the
   * normal radio CCA actions like TX-if-CCA.
   *
   * @param target_fstxon If TRUE, transition to FSTXON; if FALSE,
   * transition to TX. */
  int startTransmission_ (bool with_cca,
                          bool target_fstxon)
  {
    int rv = SUCCESS;
    #ifdef DEBUG_TX_P
    printf("st_\n\r");
    #endif
    atomic {
      //TODO: check long atomic (encapsulated)
      uint8_t strobe = RF_STX;
      uint8_t state = RF1A_S_TX;
      uint8_t rc;
      bool entered_rx = FALSE;
      register int16_t loop_limit = RADIO_LOOP_LIMIT;
      if (target_fstxon) {
        strobe = RF_SFSTXON;
        state = RF1A_S_FSTXON;
      }

      rc = call Rf1aIf.strobe(RF_SNOP);
      if (with_cca) {
        /* CCA test is valid only if in RX mode.  If necessary, enter it. */
        if (RF1A_S_RX != (RF1A_S_MASK & rc)) {
          entered_rx = TRUE;
          rc = call Rf1aIf.strobe(RF_SRX);
          // Wait until in RX mode, or failed to enter RX
          while ((RF1A_S_RX != (RF1A_S_MASK & rc))
                 && (0 <= --loop_limit)) {
            rc = call Rf1aIf.strobe(RF_SNOP);
          }
        }

        if (RF1A_S_RX == (RF1A_S_MASK & rc)) {
          rc = spinForValidRssi__();
        }

        /* If we didn't successfully stay in RX mode through all that,
         * something went wrong. */
        if (RF1A_S_RX != (RF1A_S_MASK & rc)) {
          rv = ERETRY;
        }
      }

      if (SUCCESS == rv) {
        /* Enter the appropriate TX mode.  When things settle, the
         * state should be RX or IDLE (CCA check failed, or
         * in-progress RX completed) or the target state (good to
         * transmit).  May be in CALIBRATE and SETTLING in between, so
         * loop. */
        (void)call Rf1aIf.strobe(strobe);
        do {
          rc = call Rf1aIf.strobe(RF_SNOP);
          if (with_cca
              && (RF1A_S_RX == (RF1A_S_MASK & rc))
              && (! (IFG_clearChannel & call Rf1aIf.getIn()))) {
            if (entered_rx) {
              resumeIdleMode_(TRUE);
            }
            break;
          }
        } while ((RF1A_S_RX != (RF1A_S_MASK & rc))
                 && (RF1A_S_IDLE != (RF1A_S_MASK & rc))
                 && (state != (RF1A_S_MASK & rc))
                 && (0 <= --loop_limit));
        if (state != (RF1A_S_MASK & rc)) {
          rv = ERETRY;
        }
      }
    }
    return rv;
  }

  /** Place the radio into RX mode and set the RX state to be prepared
   * for a new message.  */
  void startReception_ ()
  {
    uint8_t rc;

    atomic {
      //TODO: check long atomic (encapsulated)
      rx_state = RX_S_listening;
      // Go to receive mode now, unless in an active transmit mode
      if (transmitIsInactive_atomic_()) {
        rc = call Rf1aIf.strobe(RF_SRX);
        while ((RF1A_S_RX != (RF1A_S_MASK & rc))) {
          rc = call Rf1aIf.strobe(RF_SNOP);
        }
      }
    }
  }

  async command error_t Rf1aPhysical.startSend[uint8_t client](bool cca_check, 
      rf1a_offmode_t txOffMode){
    uint8_t rc;
    /* Radio must be assigned */
    if (! call ArbiterInfo.inUse()) {
      return EOFF;
    }
    /* This must be the right client */
    if (client != call ArbiterInfo.userId()) {
      return EBUSY;
    }
    atomic{
      HPL_ATOMIC_SET_PIN;
      //TODO: check long atomic
      /* And we can't be actively receiving anything */
      if (RX_S_listening < rx_state) {
        rc = call Rf1aIf.strobe(RF_RXSTAT | RF_SNOP);
        
        /* Another special case.  If noise on the channel causes a
         * packet reception to begin, but doesn't last long enough for
         * the interpreted packet length to be received, the radio
         * will return to idle mode.  Detect that we're in idle mode
         * with data required but not available and abort the
         * receive. */
        if ((RF1A_S_IDLE == (RF1A_S_MASK & rc))
            && (rx_received < rx_expected)
            && (0 == (rc & RF1A_S_FIFOMASK))) {
          rx_result = FAIL;
          post receiveData_task();
        }
        HPL_ATOMIC_CLEAR_PIN;
        return EBUSY;
      }

      /* And we can't already be transmitting something. */
      if (0 < tx_remain) {
        HPL_ATOMIC_CLEAR_PIN;
        return EBUSY;
      }

      /* More weirdness: seems that, even with all we've tried, it's
       * possible to end up in receive mode with pending data in the
       * transmission buffer.  If that happens, just throw it away.
       *
       * @TODO@ This is either a serious radio bug, or an error in the
       * logic of this module. It appears to occur when sendFragment_
       * has placed the complete message into the TXFIFO and
       * successfully transferred to TX mode.  Since resetting the
       * radio here is successful and operation continues, it appears
       * that in this situation the upper level has been notified that
       * the send completed, and it is only the radio that has failed
       * to do its job.  It seems likely that this module still has a
       * situation where it improperly transitions the state to RX
       * even though the transmission has not completed.
       * Experimentation indicates this is independent of CCA_MODE, is
       * observed only when another radio is active, and that this
       * module is not strobing to another state between the
       * successful STX and this point. */
      if ((RF1A_S_RX == (RF1A_S_MASK & call Rf1aIf.strobe(RF_SNOP)))
          && (TX_S_inactive == tx_state) // safety check: do not trash active transmissions
          && (0 < call Rf1aIf.readRegister(TXBYTES))) {
        // printf("ERROR: RX mode but %d TXBYTES queued, tx state %d\r\n", call Rf1aIf.readRegister(TXBYTES), tx_state);
        resetAndFlushTxFifo_();
      }

      /* Even if it's being transmitted from the radio, wait until
       * it's gone. */
      if (! transmitIsInactive_atomic_()) {
        HPL_ATOMIC_CLEAR_PIN;
        return ERETRY;
      }

      //Set up TX_OFF as indicated.
      call Rf1aIf.writeRegister(MCSM1, 
        (0xfc & call Rf1aIf.readRegister(MCSM1)) | (txOffMode));

      /* If we aren't in a transmit mode already, go to FSTXON, doing
       * the necessary CCA.  Beware: even if this succeeds, if we land
       * in FSTXON the radio will transition back to RX mode if it CCA
       * fails before we go to STX.  That's handled in
       * sendFragment_task. */
      rc = call Rf1aIf.strobe(RF_SNOP);
      if ((RF1A_S_FSTXON != (rc & RF1A_S_MASK)) && (RF1A_S_TX != (rc & RF1A_S_MASK))) {
        int rv = startTransmission_(cca_check, TRUE);
        if (SUCCESS != rv) {
          HPL_ATOMIC_CLEAR_PIN;
          return rv;
        }
        rc = RF1A_S_MASK & call Rf1aIf.strobe(RF_SNOP);
      }
      HPL_ATOMIC_CLEAR_PIN;
      return SUCCESS;
    }
  }
  

//  //TODO: should remove this, actually. just use the two-phase process
//  command error_t Rf1aPhysical.send[uint8_t client] (uint8_t* buffer,
//                                                     unsigned int length,
//                                                     bool cca_check,
//                                                     rf1a_offmode_t txOffMode){
//  {
//    uint8_t rc;
//    error_t error;
//
//    //state-checks and transition to FSTXON
//    error = call Rf1aPhysical.startSend[client](cca_check, txOffMode);
//
//    if (SUCCESS == error){
//      //ready to go
//      return call Rf1aPhysical.completeSend[client](buffer, length);
//    } else {
//      return error;
//    }
//  }
  default async event uint8_t Rf1aPhysical.getChannelToUse[uint8_t
  client](){
    return 0;
  }

  default async event void Rf1aPhysical.sendDone[uint8_t client]
  (uint8_t* buffer, uint8_t len, int result) { }

  default async event bool Rf1aPhysical.getPacket[uint8_t clientId](uint8_t** buffer, uint8_t* length){
    return FALSE;
  }

  async command error_t Rf1aPhysical.startTransmission[uint8_t client] (bool with_cca)
  {
    /* Radio must be assigned */
    if (! call ArbiterInfo.inUse()) {
      return EOFF;
    }
    /* This must be the right client */
    if (client != call ArbiterInfo.userId()) {
      return EBUSY;
    }
    return startTransmission_(with_cca, FALSE);
  }

  async command error_t Rf1aPhysical.resumeIdleMode[uint8_t client] ()
  {
    /* Radio must be assigned */
    if (! call ArbiterInfo.inUse()) {
      return EOFF;
    }
    /* This must be the right client */
    if (client != call ArbiterInfo.userId()) {
      return EBUSY;
    }
    atomic {
      HPL_ATOMIC_SET_PIN;
      if (TX_S_inactive != tx_state) { // NB: Not transmitIsInactive
        #ifdef DEBUG_TX_P
        printf("rp.rim\n\r");
        #endif
        tx_result = ECANCEL;
        //removed call to sft
//        post sendFragment_task();
      } else if (RX_S_listening < rx_state) {
        printf_SW_TOPO("RIM\r\n");
        rx_result = ECANCEL;
        post receiveData_task();
      } else {
        resumeIdleMode_(signal Rf1aPhysical.idleModeRx[client]());
      }
    }
    HPL_ATOMIC_CLEAR_PIN;
    return SUCCESS;
  }

  default async event bool Rf1aPhysical.idleModeRx[uint8_t client](){
    return TRUE;
  }

  async command error_t Rf1aPhysical.startReception[uint8_t client] ()
  {
    /* Radio must be assigned */
    if (! call ArbiterInfo.inUse()) {
      return EOFF;
    }
    /* This must be the right client */
    if (client != call ArbiterInfo.userId()) {
      return EBUSY;
    }
    atomic {
      HPL_ATOMIC_SET_PIN;
      if (0 != rx_pos) {
        HPL_ATOMIC_CLEAR_PIN;
        return EALREADY;
      }
      startReception_();
      HPL_ATOMIC_CLEAR_PIN;
    }
    return SUCCESS;
  }

  async command error_t Rf1aPhysical.sleep[uint8_t client] ()
  {
    /* Radio must be assigned */
    if (! call ArbiterInfo.inUse()) {
      return EOFF;
    }
    /* This must be the right client */
    if (client != call ArbiterInfo.userId()) {
      return EBUSY;
    }
    atomic {
      uint8_t rc;
      HPL_ATOMIC_SET_PIN;

      /* Reject sleep if actively receiving or have a transmission
       * queued or going out */
      if ((RX_S_listening < rx_state)
          || (! transmitIsInactive_atomic_())) {
        return ERETRY;
      }

      /* Have to go to idle first */
      resumeIdleMode_(FALSE);
      
      /* Now go to sleep */
      rc = call Rf1aIf.strobe(RF_SXOFF);
      while (! (0x80 & rc)) {
        rc = call Rf1aIf.strobe(RF_SNOP);
      }
      HPL_ATOMIC_CLEAR_PIN;
    }
    return SUCCESS;
  }


  /** Determine the number of bytes available in the RX FIFO following
   * the algorithm in 19.3.10. */
  unsigned int receiveCountAvailable_ ()
  {
    unsigned int avail;
    unsigned int avail2;

    avail2 = 0x7f & call Rf1aIf.readRegister(RXBYTES);
    avail = ~avail2;
    while (avail != avail2) {
      avail = avail2;
      avail2 = 0x7f & call Rf1aIf.readRegister(RXBYTES);
    }
    return avail;
  }

  /** Reset the radio and update state so the inner code of
   * receiveData_ will abort the reception.  This method should
   * only be called from within receiveData_. */
  void cancelReceive_ ()
  {
    uint8_t rc;

    /* Reset the radio */
    rc = call Rf1aIf.strobe(RF_SIDLE);
    while (RF1A_S_IDLE != (RF1A_S_MASK & rc)) {
      rc = call Rf1aIf.strobe(RF_SNOP);
    }
    rc = call Rf1aIf.strobe(RF_SFRX);
    while (RF1A_S_IDLE != (RF1A_S_MASK & rc)) {
      rc = call Rf1aIf.strobe(RF_SNOP);
    }
    resumeIdleMode_(TRUE);
  }

  /** Do the actual work of consuming data from the RX FIFO and
   * storing it in the appropriate location. */
  void receiveData_ ()
  {
    unsigned int avail;
    uint8_t client = call ArbiterInfo.userId();
    bool need_post = TRUE;
    bool signal_start = FALSE;
    bool signal_filled = FALSE;
    bool signal_complete = FALSE;
    uint8_t* start;
    unsigned int expected;
    unsigned int received;
    int result;
    error_t crcError;

    atomic {
      HPL_ATOMIC_SET_PIN;
      do {
        unsigned int need;
        unsigned int consume;

        /* Did somebody cancel the receive?  This would also happen on
         * an RX overrun. */
        if (SUCCESS != rx_result) {
          signal_complete = TRUE;
          cancelReceive_();
          break;
        }
      
        /* Is there data available?  How much?  If none, stop now. */
        //~6 uS to check
        avail = receiveCountAvailable_();
        if (0 == avail) {
          break;
        }

        /* OK, there's data; do we know how much to read? */
        if (RX_S_active > rx_state) {
          uint8_t len8;
          bool variable_packet_length_mode = (0x01 == (0x03 & call Rf1aIf.readRegister(PKTCTRL0)));

          /* @TODO@ set rx_expected when not using variable packet length mode */
          if (variable_packet_length_mode) {
            //FEC length: not encoded. reflects the number of bytes
            //  actually sent, not the encoded payload length
            call Rf1aFifo.readRXFIFO(&len8, sizeof(len8), TRUE);
            //TODO: if len8+2 > 64, we're going to be reading a bunch
            //  of extra crap out of here. 
            //The correct way to handle this would be to let this
            //  re-post itself and just make sure that the data v.
            //  control sizes are handled correctly (this would also
            //  allow for >64 bye packets). However, that complicates
            //  the CRC computation slightly and generally sounds like a
            //  real pain to debug.
            //So, maybe an easier way to handle this, given the
            //  current radio stack, would be to immediately give up,
            //  let the RXFIFO overflow happen, and then recover in
            //  the next layer up.
            //!!!Either way, we should be validating that the data length
            //  we receive is not going to overflow anything. If we
            //  get a len of 255, we are never going to read all of
            //  it.
          }else{
            len8 = call Rf1aIf.readRegister(PKTLEN);
          }

          {
            uint16_t availTimeout = 0x2ff;
            avail -= 1;
            //rx_expected: in data bytes
            rx_expected = call Rf1aFifo.getDecodedLen(len8 - call Rf1aFifo.getCrcLen()) ;
            //spin until the entire packet is available: if len8 +2 >
            //64, we're not going to wait for it all to show up.
            #if WAIT_FOR_PACKET == 1
              do{
                avail = receiveCountAvailable_();
                availTimeout --;
              //+2 = metadata 
              }while (((len8+2) <= 64) && (avail  != (len8 + 2)) && availTimeout);
              if (!availTimeout){
                printf("!rest of packet never showed up (%u, expecting %u)\r\n", 
                  avail, (len8 + 2));
              }
            #else
              avail = receiveCountAvailable_();
            #endif
          }

          /* Update the state */
          rx_state = RX_S_active;

          /* Discard any previous message start and length */
          rx_start = 0;
          rx_received = 0;

          /* Notify anybody listening that there's a message coming in */
          signal_start = TRUE;
          expected = rx_expected;
        }
        need = rx_expected - rx_received;

        /* Data and we know how much: is there any place to put it? */
        if (0 == rx_pos) {
          signal_filled = TRUE;
          rx_start = 0;
          received = 0;
          break;
        }

        /* If first data into this buffer, record message start (do
         * NOT merge with above clear of rx_start: message may require
         * multiple buffers and we need rx_start to always be within
         * the current one) */
        if (0 == rx_start) {
          rx_start = rx_pos;
        }

        /* Per 19.3.10, don't consume the last byte available unless
         * it's the last byte in the packet. */
        if (avail < need) {
          --avail;
        }

        /* Figure out how much we can and need to consume, then read it. */
        consume = rx_pos_end - rx_pos;
        if (consume > need) {
          consume = need;
        }
        if (consume > avail) {
          consume = avail;
        }
        //this is the only readburst we see
        //~17 uS from start of function to this point, 11 uS of logic
        //  in this function
        //~33uS to read data
//        printf_BF("rx %p %u\r\n", rx_pos, consume);
        //FEC: this should decode the data as we pull it out

        //TODO: this will probably be an issue if the buffer is not
        //filled when we start this process. Could spin until avail ==
        //need
        crcError = call Rf1aFifo.readRXFIFO(rx_pos, consume, FALSE);
        rx_pos += consume;
        rx_received += consume;
//        printf_FEC("A %u c %u\r\n", avail, consume);
//        avail = 0x7f & call Rf1aIf.readRegister(RXBYTES);
        /* Have we reached the end of the message? */
        if (rx_received == rx_expected) {
          /* If APPEND_STATUS is set, gotta clear out that data. */
          if (0x04 & call Rf1aIf.readRegister(PKTCTRL1)) {
            uint16_t readTimeout = 0x1fff;
            /* Better be two more octets.  Busy-wait until they show
             * up. */
            //For whatever reason, receiveCountAvailable_ seems to
            //give erroneous results here when used with FEC.  Rather
            //than trust it, we wait until it tells us there's 2 bytes
            //left or we retry too many times and fail.
            do {
              avail = receiveCountAvailable_(); //0x7f & call Rf1aIf.readRegister(RXBYTES);
              readTimeout --;
//              printf("A' %u %u\r\n", avail, readTimeout);
            }while (2 > avail && readTimeout); 
//            printf_FEC("A. %u\r\n", avail);
            if (! readTimeout){
              printf("!COULD NOT READ RX METADATA: %u avail\r\n", avail);
              rx_rssi_raw = 0x00;
              rx_lqi_raw = 0x00;
            }else{
              //TODO: if we see weird RSSI/LQI figures, then this
              //could indicate that we are in the case where extra
              //data is left in the buffer, and we read out something
              //other than the last two bytes (a.k.a. the status
              //bytes)
              //FEC: not encoded
              call Rf1aFifo.readRXFIFO(&rx_rssi_raw,
                sizeof(rx_rssi_raw), TRUE);
              call Rf1aFifo.readRXFIFO(&rx_lqi_raw, sizeof(rx_lqi_raw),
                TRUE);
            }
            //flush out the rest of the RXFIFO if there's anything
            //left.
            while (receiveCountAvailable_()){
              uint8_t garbage;
              call Rf1aFifo.readRXFIFO(&garbage, sizeof(garbage), TRUE);
            }
            //crcError is FAIL if some codewords had detectable but
            //uncorrected bit errors. 
            //This is not as strong as a full CRC.
            if (call Rf1aFifo.crcOverride()){
              if (SUCCESS == crcError){
                rx_lqi_raw |= 0x80;
              }else{
                rx_lqi_raw &= 0x7f;
              }
            }
            avail -= 2;
          }

          signal_complete = TRUE;

          /* Note: received is the number of bytes in this packet, not in
           * the total message.  Sorry. */
          received = rx_pos - rx_start;

          /* If in one-shot mode, shift the buffer end down so we signal filled. */
          if (rx_single_use) {
            rx_pos_end = rx_pos;
          }
        }

        /* Have we used up the receive buffer? */
        if (rx_pos_end == rx_pos) {
          signal_filled = TRUE;
          /* In one-shot mode, if we didn't get the whole message,
           * mark it failed. */
          if (rx_single_use && (! signal_complete)) {
//            printf("!expected %u received %u", rx_expected, rx_received);
            rx_result = ENOMEM;
          }
          received = rx_pos - rx_start;
          rx_pos = 0;
        }

      //11 uS from readBurstRegister above to end of loop
      } while (0);
      /* If there's still data available, we'll have to come back,
       * even if we've finished this message. */
      //~6 uS to check
      need_post = (0 < receiveCountAvailable_());
      printf_FEC("NP: %x\r\n", need_post);
      /* Extract the start of any filled buffer (length was set above) */
      if (signal_filled) {
        start = rx_start;
      }

      if (signal_complete) {
        result = rx_result;
        if (SUCCESS == result) {
          start = rx_start;
        } else {
          start = 0;
          received = 0;
        }
        // received must have been set earlier before state was updated
        
        /* Reset for next message */
        rx_result = SUCCESS;
        if (rx_single_use) {
          rx_pos = 0;
        }
        if (rx_pos) {
          rx_state = RX_S_listening;
        } else {
          rx_state = RX_S_inactive;
        }
      }
      HPL_ATOMIC_CLEAR_PIN;
    } // atomic

    /* Repost the receive task if there's more work to be done. */
    if (need_post) {
//      printf("REPOST\r\n");
      post receiveData_task();
    }
    //~3 uS from need_post assignment above
    /* Announce the start of a message first, then completion of the
     * message, and finally that we need another receive buffer (if
     * any of these events happen to occur at the same time). */
    if (signal_start) {
      signal Rf1aPhysical.receiveStarted[client](expected);
    }
    if (signal_complete) {
///* sniffer begin *************************************************************/
//    uint8_t k;
//    for(k = 0; k < received; k++){
//      printf("%02X", start[k]);
//    }
//    printf(" %d %u %x\r\n", 
//      rssiConvert_dBm(rx_rssi_raw),
//      rx_lqi_raw & 0x7f, 
//      (rx_lqi_raw & 0x80));
///* sniffer end ***************************************************************/
      sniffPacket(start, received, rx_rssi_raw, rx_lqi_raw);
      signal Rf1aPhysical.receiveDone[client](start, received, result);
    }
    if (signal_filled) {
      signal Rf1aPhysical.receiveBufferFilled[client](start, received);
    }
    //~7 uS from start of signal checks
  }

  #if CX_SNIFF_ENABLED == 1
    #warning "CX Sniff enabled"

    #define SNIFFER_PKT_LEN 64
    #define SNIFFER_QUEUE_LEN 16
    typedef struct sniffed_packet_t {
      uint8_t pkt[SNIFFER_PKT_LEN];
      uint8_t received;
      uint8_t rssi;
      uint8_t lqi;
    } sniffed_packet_t;
  
    sniffed_packet_t sniffQueue[SNIFFER_QUEUE_LEN];
    uint8_t startSniffed = 0;
    uint8_t endSniffed = 0;

    void doSniffPacket(uint8_t* pkt, uint8_t received, uint8_t rssi,
      uint8_t lqi);
    task void sniffNext();
  
    void sniffPacket(uint8_t* pkt, uint8_t received, uint8_t rssi,
        uint8_t lqi){
      uint8_t i;
      sniffed_packet_t* cur;
  //    printf("%02X -> %d\r\n", pkt[2], endSniffed);
  //    return;
      if (((endSniffed+1)%SNIFFER_QUEUE_LEN) == startSniffed){
        printf("SNIFFER OVERFLOW\r\n");
      } else{
        cur = &sniffQueue[endSniffed];
//        printf("W %p\r\n", cur);
        for (i=0; i< SNIFFER_PKT_LEN; i++){
          cur->pkt[i] = pkt[i];
        }
        cur -> received = received;
        cur -> rssi = rssi;
        cur -> lqi = lqi;
        post sniffNext();
        endSniffed = (endSniffed + 1)%SNIFFER_QUEUE_LEN;
      }
    }

    task void sniffNext(){
      if (startSniffed != endSniffed){
        sniffed_packet_t* cur;
        atomic{
          cur = &sniffQueue[startSniffed];
          startSniffed = (startSniffed+1)%SNIFFER_QUEUE_LEN;
        }
        printf("R %p %u\r\n", cur, cur->received);
        doSniffPacket(cur->pkt, cur->received, cur->rssi, cur->lqi);
        post sniffNext();
      }
    }
  
    void doSniffPacket(uint8_t* pkt, uint8_t received, uint8_t rssi,
      uint8_t lqi){
        uint8_t k;
        message_t* msg = (message_t*)pkt;
        uint8_t crcPassed = (lqi & 0x80);
        uint8_t lqiVal = (lqi&0x7f);
        int8_t rssiConv = rssiConvert_dBm(rssi); 
  
        cx_header_t* cxHdr = (cx_header_t*)(&msg->data[-1]);
        message_header_t* msgHdr = (message_header_t*)(msg->header);
        rf1a_ieee154_t* ieee154Hdr = (rf1a_ieee154_t*)msgHdr;
        printf("S ");
        for(k = 0; k < SNIFFER_PKT_LEN ; k++){
          printf("%02X", pkt[k]);
        }
        printf(" %d %u %x\r\n", 
          rssiConv,
          lqiVal,
          crcPassed);
        //To match with SD:
        //np source sn count frameNum
        printf("CXS %u %u %u %u %u %d %u %x\r\n",
          cxHdr -> nProto,
          ieee154Hdr -> src,
          cxHdr -> sn,
          cxHdr -> count,
          cxHdr -> count + cxHdr -> originalFrameNum - 1,
          rssiConv,
          lqiVal,
          crcPassed);
    }
  #else
  void sniffPacket(uint8_t* pkt, uint8_t received, uint8_t rssi,
      uint8_t lqi){}
  #endif
   
  #define STEPSIZE 1
  #define NUMSTEPS 16 
  bool hasPrintedAddrs = FALSE;
  task void reportSRB(){
    uint8_t i;
    if (!hasPrintedAddrs){
      hasPrintedAddrs = TRUE;
      printf_BF("%p ", &rx_state);
      for(i=STEPSIZE*NUMSTEPS; i > 0; i-=STEPSIZE){
        printf_BF("%p ", (&rx_state)-i);
      }
      printf_BF("\r\n");
    }

    for(i=STEPSIZE*NUMSTEPS; i > 0; i-=STEPSIZE){
      printf_BF("%x ", *((uint8_t*)&rx_state-i));
    }
    printf_BF("\r\n");
  }

  async command error_t Rf1aPhysical.setReceiveBuffer[uint8_t client] (uint8_t* buffer,
                                                                       unsigned int length,
                                                                       rf1a_offmode_t rxOffMode){

//    printf_BF("srb %p\r\n", buffer);
//    post reportSRB();
    /* Radio must be assigned */
    if (! call ArbiterInfo.inUse()) {
      return EOFF;
    }
    /* This must be the right client */
    if (client != call ArbiterInfo.userId()) {
      printf_BF("wrong client\r\n");
      return EBUSY;
    }
    /* Buffer and length must be realistic; if either bogus, clear them both
     * and disable reception. */
    if ((! buffer) || (0 == length)) {
      buffer = 0;
      length = 0;
    }
    atomic {
      HPL_ATOMIC_SET_PIN;
      /* If there's a buffer in play and we're actively receiving into
       * it, reject the attempt. */
      if (rx_pos && (RX_S_listening < rx_state)) {
        #ifdef DEBUG_RX
        P2OUT &= ~BIT4;
        #endif
        #ifdef DEBUG_SET_RX_BUFFER
        P1OUT |= BIT1;
        #endif
        printf_BF("receiving: %x\r\n", rx_state);
        HPL_ATOMIC_CLEAR_PIN;
        return EBUSY;
      }

      rx_pos = buffer;
      rx_pos_end = buffer + length;
      rx_start = 0;
      rx_single_use = TRUE;


      // Set up for post-rx transition
      call Rf1aIf.writeRegister(MCSM1, 
        (0xf3 & call Rf1aIf.readRegister(MCSM1)) | (rxOffMode << 2));
      if (0 == rx_pos) {
        /* Setting a null buffer acts to cancel any in-progress
         * reception. */
        if (RX_S_listening < rx_state) {
          printf_SW_TOPO("SRB\r\n");
          rx_result = ECANCEL;
          //make sure we return to RX after this.
          call Rf1aIf.writeRegister(MCSM1, 0xff );
          post receiveData_task();
        } else {
          rx_state = RX_S_inactive;
          /* Return to IDLE now, if not transmitting */
          if (transmitIsInactive_atomic_()) {
            resumeIdleMode_(TRUE);
          }
        }
      } else if (RX_S_inactive == rx_state) {
        startReception_();
      }
      HPL_ATOMIC_CLEAR_PIN;
    }
    return SUCCESS;
  }

  default async command unsigned int Rf1aTransmitFragment.transmitReadyCount[uint8_t client] (unsigned int count)
  {
    return call Rf1aPhysical.defaultTransmitReadyCount[client](count);
  }
  async command unsigned int Rf1aPhysical.defaultTransmitReadyCount[uint8_t client] (unsigned int count)
  {
    atomic {
      return transmitReadyCount_(client, count);
    }
  }

  default async command const uint8_t* Rf1aTransmitFragment.transmitData[uint8_t client] (unsigned int count)
  {
    return call Rf1aPhysical.defaultTransmitData[client](count);
  }
  async command const uint8_t* Rf1aPhysical.defaultTransmitData[uint8_t client] (unsigned int count)
  {
    atomic {
      return transmitData_(client, count);
    }
  }

  async event void Rf1aInterrupts.rxFifoAvailable[uint8_t client] ()
  {
    if (RX_S_inactive < rx_state) {
      /* If we have data, and the state doesn't reflect that we're
       * receiving, bump the state so we know to fast-exit out of
       * transmit to allow receiveData_task to run. */
      if ((RX_S_listening == rx_state)
          && (0 < receiveCountAvailable_())) {
        rx_state = RX_S_synchronized;
      }
      post receiveData_task();
    }
  }

  async event void Rf1aInterrupts.txFifoAvailable[uint8_t client] ()
  {
    if (TX_S_inactive != tx_state) {
      uint8_t txbytes = call Rf1aIf.readRegister(TXBYTES);

      /* Remember those other comments warning of an odd behavior
       * where we can pass CCA, put the radio into TX, load up the
       * TXFIFO, then find ourselves in RX with a new tattoo, no
       * memory of the night before, and a full TXFIFO?  This check
       * catches one situation where that happens.  Clearly if the
       * radio's saying there's room, and there isn't, something's
       * wrong. No idea why we get this interrupt in that case, but
       * we're grateful nonetheless. */
      if (0x3F <= (0x7F & txbytes)) {
        #ifdef DEBUG_TX_P
        printf("ri.txfifo trouble\n\r");
        #endif
        tx_result = ECANCEL;
      }
      //we should get this interrupt when txfifo is drained. wait
      //until the last byte is actually in the air.
      if (0 == txbytes){
        call Rf1aIf.writeRegister(FIFOTHR, tx_cached_fifothr);
        //disable the interrupt
        call Rf1aIf.setIe(call Rf1aIf.getIe() &
          ~IFG_txFifoAboveThreshold);

        /* This might be an erratum, but I think it's really that
         * the fact the TXFIFO has flushed still doesn't mean the
         * transmission is done: that last character still needs
         * to be spat out the antenna.  Unfortunately, I don't
         * know of another way to detect that the transmission has
         * really-and-fortrue completed.
         *
         * Without this check, we can return to main program
         * control and proceed to initiate a second send before
         * the MRCSM finishes cleaning up from the previous
         * transmit.  When this happens, the radio appears to
         * accept the subsequent command but never actually
         * transmits it.
         *
         * What this does is busy-wait until MARCSTATE gets out of
         * TX; this appears to be sufficient (in the test
         * configuration, it reaches TX_END).  Instrumentation
         * indicates this loop runs about 350 times before MRCSM
         * transitions out of TX.  I'm not going to put a limit on
         * it, because if this ever stops working I want it to
         * hang here, where inspection via the debugger will find
         * it and the poor maintainer will at least have this
         * comment to provide a clue as to what might be going on.
         *
         * When that happens, consider checking whether TX_OFF is
         * set to "stay in TX", since in that case I don't know
         * MRCSM ever transitions to TX_END.  I would expect it
         * does, but then I'd expect the radio to work better than
         * it does.... */
        //busy wait until it's in the air.
        {
          uint8_t ms;
          do {
            ms = call Rf1aIf.readRegister(MARCSTATE);
          } while (MRCSM_TX == ms);
        }

        tx_state = TX_S_inactive;
        sniffPacket(tx_buffer, tx_length, 0xFF, 0xFF);
        signal Rf1aPhysical.sendDone[tx_client](tx_buffer, tx_length, SUCCESS);
      }      
    }
  }

  async event void Rf1aInterrupts.rxOverflow[uint8_t client] ()
  {
    atomic {
      printf("!RXOVERFLOW\r\n");
      rx_result = ECANCEL;
      post receiveData_task();
    }
  }
  async event void Rf1aInterrupts.txUnderflow[uint8_t client] ()
  {
    atomic {
      tx_result = FAIL;
      #ifdef DEBUG_TX_P
      printf("ri.txu\n\r");
      #endif
//      post sendFragment_task();
    }
  }
  async event void Rf1aInterrupts.syncWordEvent[uint8_t client] ()
  {
    signal Rf1aPhysical.frameStarted[call ArbiterInfo.userId()]();
  }

  async event void Rf1aInterrupts.clearChannel[uint8_t client] ()
  {
    signal Rf1aPhysical.clearChannel[call ArbiterInfo.userId()]();
  }

  async event void Rf1aInterrupts.carrierSense[uint8_t client] ()
  {
    signal Rf1aPhysical.carrierSense[call ArbiterInfo.userId()]();
  }

  async event void Rf1aInterrupts.coreInterrupt[uint8_t client] (uint16_t iv)
  {
    signal Rf1aCoreInterrupt.interrupt[call ArbiterInfo.userId()](iv);
  }

  default async event void Rf1aCoreInterrupt.interrupt[uint8_t client](uint16_t iv){ }
      
  default async event void Rf1aPhysical.receiveStarted[uint8_t client] (unsigned int length) { }

  default async event void Rf1aPhysical.receiveDone[uint8_t client] (uint8_t* buffer,
                                                                     unsigned int count,
                                                                     int result) { }

  default async event void Rf1aPhysical.receiveBufferFilled[uint8_t client] (uint8_t* buffer,
                                                                             unsigned int count) { }

  default async event void Rf1aPhysical.frameStarted[uint8_t client] () { }
  default async event void Rf1aPhysical.clearChannel[uint8_t client] () { }
  default async event void Rf1aPhysical.carrierSense[uint8_t client] () { }
  
  default async event void Rf1aPhysical.released[uint8_t client] () { }
  
  async command rf1a_status_e Rf1aStatus.get ()
  {
    uint8_t rc = call Rf1aIf.strobe(RF_SNOP);
    if (rc & 0x80) {
      return RF1A_S_OFFLINE;
    }
    return (rf1a_status_e)(RF1A_S_MASK & rc);
  }

  async command int Rf1aPhysical.getChannel[uint8_t client] ()
  {
    /* Radio must be assigned */
    if (! call ArbiterInfo.inUse()) {
      return -EOFF;
    }
    /* This must be the right client */
    if (client != call ArbiterInfo.userId()) {
      return EBUSY;
    }
    return call Rf1aIf.readRegister(CHANNR);
  }

  async command int Rf1aPhysical.setChannel[uint8_t client] (uint8_t channel)
  {
    /* Radio must be assigned */
    if (! call ArbiterInfo.inUse()) {
      return EOFF;
    }
    /* This must be the right client */
    if (client != call ArbiterInfo.userId()) {
      return EBUSY;
    }
    atomic {
      bool radio_online;
      uint8_t rc = call Rf1aIf.strobe(RF_SNOP);

      /* The radio must not be actively receiving or transmitting. */
      if ((TX_S_inactive != tx_state)
          || (RX_S_listening < rx_state)
          || (RF1A_S_FSTXON == (rc & RF1A_S_MASK))
          || (RF1A_S_TX == (rc & RF1A_S_MASK))) {
        return ERETRY;
      }

      /* If radio is not asleep, make sure it transitions to IDLE then
       * back to its normal mode.  With MCSM0.FS_AUTOCOL set to 1
       * (normal with our configurations) this ensures recalibration
       * to the new frequency. */
      radio_online = (RF1A_S_OFFLINE != call Rf1aStatus.get());
      if (radio_online) {
        resumeIdleMode_(FALSE);
      }
      call Rf1aIf.writeRegister(CHANNR, channel);
      if (radio_online) {
        resumeIdleMode_(TRUE);
      }
    }
    return SUCCESS;
  }

  async command void Rf1aPhysical.reconfigure[uint8_t client](){
    call ResourceConfigure.unconfigure[client]();
    call ResourceConfigure.configure[client]();
  }

  enum {
    /** SLAU259 table 19-15 provides the RSSI_offset value. */
    RSSI_offset = 74,
  };

  /** Algorithm described in 19.3.8 to convert RSSI from register
   * value to absolute power level. */
  int rssiConvert_dBm (uint8_t rssi_dec_)
  {
    int rssi_dec = rssi_dec_;
    if (rssi_dec >= 128) {
      return ((rssi_dec - 256) / 2) - RSSI_offset;
    }
    return (rssi_dec / 2) - RSSI_offset;
  }

  async command int Rf1aPhysical.rssi_dBm[uint8_t client] ()
  {
    int rv;
    
    /* Radio must be assigned */
    if (! call ArbiterInfo.inUse()) {
      return EOFF;
    }
    /* This must be the right client */
    if (client != call ArbiterInfo.userId()) {
      return EBUSY;
    }
    atomic {
      uint8_t rc = call Rf1aIf.strobe(RF_SNOP);
      if (RF1A_S_RX == (RF1A_S_MASK & rc)) {
        (void)spinForValidRssi__();
      }
      rv = rssiConvert_dBm(call Rf1aIf.readRegister(RSSI));
    }
    return rv;
  }

  async command void Rf1aPhysicalMetadata.store (rf1a_metadata_t* metadatap)
  {
    atomic {
      metadatap->rssi = rx_rssi_raw;
      metadatap->lqi = rx_lqi_raw;
    }
  }

  async command int Rf1aPhysicalMetadata.rssi (const rf1a_metadata_t* metadatap)
  {
    return rssiConvert_dBm(metadatap->rssi);

  }
  async command int Rf1aPhysicalMetadata.lqi (const rf1a_metadata_t* metadatap)
  {
    /* Mask off the CRC check bit */
    return metadatap->lqi & 0x7F;
  }

  async command bool Rf1aPhysicalMetadata.crcPassed (const rf1a_metadata_t* metadatap)
  {
    /* Return only the CRC check bit */
    return metadatap->lqi & 0x80;
  }


}

/* 
 * Local Variables:
 * mode: c
 * End:
 */
