/* -*- mode:c++; indent-tabs-mode:nil -*-
 * Copyright (c) 2007, Technische Universitaet Berlin
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * - Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the distribution.
 * - Neither the name of the Technische Universitaet Berlin nor the names
 *   of its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 * OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
 * USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
/**
 * hand rolled bsl tool, other ones are too slow
 * @author Andreas Koepke <koepke at tkn.tu-berlin.de>
 * @date 2007-04-16
 * @author Doug Carlson <carlson@cs.jhu.edu>
 * - Extensive modifications for compatibility with flash-based BSLs.
 */
#ifndef BSL_SERIAL_H
#define BSL_SERIAL_H

#include <stdio.h>
#include <string>
#include <inttypes.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <sys/types.h>
#include <termios.h>
#include <unistd.h>
#include <iostream>
#include <errno.h>
#include <linux/serial.h>
#include "Parameters.h"

using namespace std;


inline void serial_delay(unsigned usec) {
    struct timeval tv;
    tv.tv_sec = usec/1000000;
    tv.tv_usec = usec%1000000;
    select(0,NULL,NULL,NULL, &tv);
};

#ifndef BSL_CORE_LEN
#define BSL_CORE_LEN 256
#endif

#define BSL_CRC_LEN 2

struct addr_frame_header_t {
  uint8_t AL;
  uint8_t AM;
  uint8_t AH;
} __attribute__ ((packed));

struct addr_frame_t {
  addr_frame_header_t header;
  uint8_t body[BSL_CORE_LEN - sizeof(addr_frame_header_t) + BSL_CRC_LEN ];
} __attribute__ ((packed));

struct bsl_core_frame_t {
  uint8_t CMD;
  union {
    uint8_t body[BSL_CORE_LEN - 1 + BSL_CRC_LEN];
    addr_frame_t addrFrame;
  } ;
} __attribute__ ((packed));

struct frame_t {
    uint8_t SYNC;
    uint8_t NL;
    uint8_t NH;
    union{
      bsl_core_frame_t core;
      uint8_t body[BSL_CORE_LEN + BSL_CRC_LEN];
    };
} __attribute__ ((packed));

void printFrame(frame_t* frame);
/**
 * Connect with serial device (dev), returns the opened file descriptors in *
 * readFD and writeFD. Returns on error with something != 0 and errno is *
 * hopefully set correctly.
*/
int serial_connect(int* err, const char* dev, int* readFD, int* writeFD, termios* pt);

class BaseSerial {
protected:
    const int switchdelay;
    termios oldtermios;

protected:
    int serialReadFD;
    int serialWriteFD;
    bool invertTest;
    bool invertReset;
    bool swapRstTest;

    fd_set rfds;

    enum {
	SYNC = 0x80,
	ACK = 0x00,
	HEADER_INCORRECT = 0x51,
	CHECKSUM_INCORRECT = 0x52,
	PACKET_SIZE_ZERO = 0x53,
	PACKET_EXCEEDS_BUFFER = 0x54,
	UNKNOWN_ERROR = 0x55,
	UNKNOWN_BAUD_RATE = 0x56,
    };

 public:
    inline int initADG715(int *err){
	  /* ADG715: from cc430-bsl line 166 */
      return setRstTck(1, 1, err);
    }

 protected:
    inline int setDTR(int *err) {
        int i = TIOCM_DTR;
        int r = ioctl(serialWriteFD, TIOCMBIS, &i);
        if(r == -1) {
            *err = errno;
            std::cerr << "ERROR: BaseSerial::setDTR could not set DTR pin" << std::endl;
        }
        return r;
    }
    inline int clrDTR(int *err) {
        int i = TIOCM_DTR;
        int r = ioctl(serialWriteFD, TIOCMBIC, &i);
        if(r == -1) {
            *err = errno;
            std::cerr << "ERROR: BaseSerial::clrDTR could not clr DTR pin" << std::endl;
        }
        return r;
    }
    inline int setRTS(int *err) {
        int i = TIOCM_RTS;
        int r = ioctl(serialWriteFD, TIOCMBIS, &i);
        if(r == -1) {
            *err = errno;
            std::cerr << "ERROR: BaseSerial::setRTS could not set RTS pin" << std::endl;
        }
        return r;
    }
    inline int clrRTS(int *err) {
        int i = TIOCM_RTS;
        int r = ioctl(serialWriteFD, TIOCMBIC, &i);
        if(r == -1) {
            *err = errno;
            std::cerr << "ERROR: BaseSerial::clrRTS could not clr RTS pin" << std::endl;
        }
        return r;
    }

    int setTEST(int *err) {
        int r;
//        cout << "SetTEST 1" << endl;
        if(invertTest) {
            r = setDTR(err);
        } else {
            r = clrDTR(err);
        }
        return r;
    }

    int clrTEST(int *err) {
        int r;
//        cout << "SetTEST 0" << endl;
        if(invertTest) {
            r = clrDTR(err);
        } else {
            r = setDTR(err);
        }
        return r;
    }

    int setRSTn(int *err) {
        int r;
//        cout << "SetRSTn 1" << endl;
        if(invertReset) {
            r = setRTS(err);
        } else {
            r = clrRTS(err);
        }
        return r;
    }

    int clrRSTn(int *err) {
        int r;
//        cout << "SetRSTn 0" << endl;
        if(invertReset) {
            r= clrRTS(err);
        } else {
            r = setRTS(err);
        }
        return r;
    }

	/*************************************************************************/
	/* Begin ADG715 Section                                                  */
	/*************************************************************************/

	/**
	 * def adg715SetSCL(self, level):
     *     "adjust ADG715 SCL (I2C clock) pin"
     *     self.serialport.setRTS(not level)
	 */
    int adg715SetSCL(int level, int *err) {
		int r;

		if(!level) {
			r = setRTS(err);
		} else {
			r = clrRTS(err);
		}

		return r;
	}

	/**
	 * def adg715SetSDA(self, level):
     *     "adjust ADG715 SDA (I2C data) pin"
     *     self.serialport.setDTR(not level)
     */
    int adg715SetSDA(int level, int *err) {
		int r;

		if(!level) {
			r = setDTR(err);
		} else {
			r = clrDTR(err);
		}

		return r;
	}

	/**
	 *	def adg715I2CStart(self):
	 *		"""
	 *		get the ADG715's attention.
	 *		start condition p.13 ADG714_715.pdf: sec 1. SDA 1->0 with SCL 1.
	 *		"""
	 *		self.adg715SetSDA(1)
	 *		self.adg715SetSCL(1)
	 *		self.adg715SetSDA(0)
	 *		time.sleep(2e-6)       # ensure we don't go too fast
	 */
	int adg715I2CStart(int *err) {
		int r;

		// need error and return value recombine function
		r = adg715SetSDA(1, err);
		r = adg715SetSCL(1, err);
		r = adg715SetSDA(0, err);
	 	usleep(2);

	 	return r;
	}

	/**
	 *	def adg715I2CStop(self):
	 * 		"""
	 *		finish an interchange with the ADG715 latch.
	 *		stop condition p.13 ADG714_715.pdf: sec 3. SDA 0->1 with SCL 1.
	 *		"""
	 *		self.adg715SetSDA(0)
	 *		self.adg715SetSCL(1)
	 *		self.adg715SetSDA(1)
	 *		time.sleep(2e-6)       # ensure we don't go too fast
	 */
	int adg715I2CStop(int *err) {
		int r;

		// need error and return value recombine function
		r = adg715SetSDA(0, err);
		r = adg715SetSCL(1, err);
		r = adg715SetSDA(1, err);
	 	usleep(2);

	 	return r;
	}

	/**
	 *	def adg715I2CWriteBit(self, bit):
	 *		"""
	 *		write bit to ADG715 p.13 ADG714_715.pdf: sec 2. and figures 4 and 5.
	 *		SDA transition must occur when SCL is low.
	 *		SDA must be stable during high period of SCL.
	 *		bring SCL low again at end of bit.
	 *		ADG715 clock is 400 kHz max (2.5 us cycle time)
	 *		"""
	 *		self.adg715SetSCL(0)
	 *		self.adg715SetSDA(bit)  # SDA transition must occur when SCL is low
	 *		time.sleep(2e-6)       # ensure we don't go too fast
	 *		self.adg715SetSCL(1)    # SDA must be stable during high period of SCL
	 *		time.sleep(2e-6)       # ensure we don't go too fast
	 *		self.adg715SetSCL(0)    # bring SCL low again at end of bit.
	 */
	int adg715I2CWriteBit(int bit, int *err) {
		int r;

	 	r = adg715SetSCL(0, err);
	 	r = adg715SetSDA(bit, err);	// SDA transition must occur when SCL is low
	 	usleep(2);		     		// ensure we don't go too fast
	 	r = adg715SetSCL(1, err);	// SDA must be stable during high period of SCL
	 	usleep(2);					// ensure we don't go too fast
	 	r = adg715SetSCL(0, err);	// bring SCL low again at end of bit.

		return r;
	}

	/**
	 *	def adg715I2CWriteByte(self, byte):
	 *		"""
	 *		write byte to ADG715.
	 *		p.13 ADG714_715.pdf: sec 2. 8 data bits plus an ack bit.
	 *		figures 4 and 5: MSB to LSB.
	 *		"""
	 *		self.adg715I2CWriteBit( byte & 0x80 ); # figures 4 and 5: MSB to LSB
	 *		self.adg715I2CWriteBit( byte & 0x40 );
	 *		self.adg715I2CWriteBit( byte & 0x20 );
	 *		self.adg715I2CWriteBit( byte & 0x10 );
	 *		self.adg715I2CWriteBit( byte & 0x08 );
	 *		self.adg715I2CWriteBit( byte & 0x04 );
	 *		self.adg715I2CWriteBit( byte & 0x02 );
	 *		self.adg715I2CWriteBit( byte & 0x01 );
	 *		self.adg715I2CWriteBit( 0 );  # "acknowledge"
	 */
	int adg715I2CWriteByte(int byte, int *err) {
		int r;

		r = adg715I2CWriteBit( byte & 0x80, err ); // figures 4 and 5: MSB to LSB
		r = adg715I2CWriteBit( byte & 0x40, err );
		r = adg715I2CWriteBit( byte & 0x20, err );
		r = adg715I2CWriteBit( byte & 0x10, err );
		r = adg715I2CWriteBit( byte & 0x08, err );
		r = adg715I2CWriteBit( byte & 0x04, err );
		r = adg715I2CWriteBit( byte & 0x02, err );
		r = adg715I2CWriteBit( byte & 0x01, err );
		r = adg715I2CWriteBit( 0          , err ); // "acknowledge"

		return r;
	}


	/*
     *	### I2C address byte prefix for ADG715: ADG714_715.pdf p.12 par. 2
     */
#define ADG715_PREFIX	0x90

	/*
     *	### select based on configuration of A0 and A1 lines as 0x0 through 0x3.
     *	### for the SuRF board, A0 and A1 are tied to GND
	 */
#define ADG715_ADDR		0x00

	/*
	 *	### ADG715 read and write
	 */
#define ADG715_READ		0x01
#define ADG715_WRITE	0x00

	/*
     *	### ADG715 address byte map:
     *	###   +---+---+---+---+---+----+----+------+
     *	###   | 1 | 0 | 0 | 1 | 0 | A1 | A0 | R/Wn |
     *	###   +---+---+---+---+---+----+----+------+
     *
     *	### ADG715 command byte:
     */
#define ADG715_COMMAND		ADG715_PREFIX | (ADG715_ADDR << 1) | ADG715_WRITE

	/*
	 *	def adg715I2CWriteLatch(self, latchState):
	 *		"""
	 *		set the state of the ADG715 latch.
	 *		get chip's attention, send address, send switch state, disconnect.
	 *		"""
	 *		debug(5, "adg715I2CWriteLatch: %x"%(latchState))
	 *		self.adg715I2CStart()
	 *		self.adg715I2CWriteByte( self.ADG715_COMMAND )
	 *		self.adg715I2CWriteByte( latchState )
	 *		### latch has now updated...
	 *		self.adg715I2CStop()
	 */
	int adg715I2CWriteLatch(int latchState, int *err) {
		int r;

		r = adg715I2CStart(err);
		r = adg715I2CWriteByte( ADG715_COMMAND, err );
		r = adg715I2CWriteByte( latchState, err );
		// latch has now updated...
		r = adg715I2CStop(err);

		return r;
	}

	/*
	 *	def setRstTck(self, Rst, Tck):
	 *		"""
	 *		Set the state of the RST and SBWTCK lines.
	 *
	 *		On SuRF:
	 *		 - RSTn has pullup and S1 is connected to RSTn
	 *		   - S1 open: RSTn high
	 *		   - S1 closed: RSTn low
	 *		 - SBWTCK has pullup and S2 is connected to SBWTCK
	 *		   - S2 open: SBWTCK high
	 *		   - S2 closed: SBWTCK low
	 *		"""
	 *		debug(4, "setRstTck: %x %x"%(Rst, Tck))
	 *		latchState = ((Rst and 1 or 0)  |     \
	 *					  (Tck and 2 or 0)) ^ 0x3
	 *		self.adg715I2CWriteLatch(latchState)
	 */
	int setRstTck(int Rst, int Tck, int *err) {
		int r;

		int latchState = ((Rst ? 1 : 0) | (Tck ? 2 : 0)) ^ 0x03;

		r = adg715I2CWriteLatch(latchState, err);

		return r;
	}

	/*************************************************************************/
	/* End ADG715 Section                                                  */
	/*************************************************************************/


    inline uint16_t calcChecksum(frame_t* frame){
        uint8_t i;
        uint8_t frameLen = (frame->NH << 8) + frame->NL;
        uint16_t crc = 0xffff;
        for(i = 0; i < frameLen; i++) {
            //printf("crc [%d]: \t%x\n\r", i, crc);
            uint8_t byte = frame->body[i];
            crc  = ((crc >> 8) | (crc << 8)) & 0xffff;
            crc ^= byte;
            crc ^= (crc & 0xf0) >> 4;
            crc ^= (crc & 0x0f) << 12;
            crc ^= (crc & 0xff) << 5;
        }
        //printf("final crc: \t%x\n\r", crc);
        return crc;
    }

    inline void checksum(frame_t *frame) {
//        printf("Checksumming:\n\r");
//        printFrame(frame);
        uint8_t frameLen = (frame->NH << 8) + frame->NL;
        uint16_t crc = calcChecksum(frame);
        frame->body[frameLen] = crc & 0xff;
        frame->body[frameLen+1] = ((crc >> 8) & 0xff);
    }

    inline bool verifyChecksum(frame_t* frame){
        uint16_t frameLen = (frame->NH << 8) + frame->NL;
        uint16_t computedCRC = calcChecksum(frame);
        uint16_t receivedCRC = *(uint16_t*)&frame->body[frameLen];
        uint8_t ckl = frame->body[frameLen];
        uint8_t ckh = frame->body[frameLen+1];
        uint8_t computedL = computedCRC & 0xff;
        uint8_t computedH = (computedCRC >> 8) & 0xff;
        //printf("Comparing computed %x to received %x (l: %x h:%x) (l:%x h:%x)\n\r", computedCRC, receivedCRC, ckl, ckh, computedL, computedH);
        return (ckl == computedL) && (ckh == computedH);
    }

    int readFD(int *err, char *buffer, int count, int maxCount);
    virtual int setPins(int *err);
    virtual int resetPins(int *err);

public:
    BaseSerial(const termios& term, int rFD, int wFD, bool T=false, bool R=false) :
        switchdelay(30000),
        oldtermios(term),
        serialReadFD(rFD), serialWriteFD(wFD),
        invertTest(T), invertReset(R) {
        int err;
        FD_ZERO(&rfds);
        setPins(&err);
    }

    virtual ~BaseSerial() {
        int r;
        int err;
        if((serialReadFD != -1) || (serialWriteFD != -1))  {
            r = disconnect(&err);
        }
    }

    // communicate
    inline int clearBuffers(int *err) {
        int r = tcflush(serialReadFD, TCIOFLUSH);
        if(r != 0) {
            *err = errno;
        }
        else {
            r = tcflush(serialWriteFD, TCIOFLUSH);
            if(r != 0) {
                *err = errno;
            }
        }
        return r;
    };

    int txrx(int *err, bool responseExpected, frame_t *txframe, frame_t *rxframe);

    // handle connection
    int disconnect(int *err);

    // change connection speed
    int highSpeed(int *err);

    // do initial magic on serial interface
    virtual int reset(int *err);
    virtual int bslExitReset(int *err);
    virtual int invokeBsl(int *err);

};

#endif
