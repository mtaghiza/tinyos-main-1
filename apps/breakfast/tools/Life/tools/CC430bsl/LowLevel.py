import serial
import time
import pdb

from tools.CC430bsl.Debug import Debug
from tools.CC430bsl.BSLExceptions import *
from tools.CC430bsl.hexl import hexl


class LowLevel(object):
    "low level communication"

    DEFAULT_TIMEOUT = 0.5

    MAX_DATA_BYTES  = 240

    MAX_PI_SIZE = 256

    ### BSL response code in txFrame
    XCODE = {
        0x51: BadHeader,
        0x52: BadChecksum,
        0x53: EmptyPacket,
        0x54: PacketTooLong,
        0x55: UnknownError,
        0x56: BadBaudRate,
    }

    ### BSL response error in rxFrame
    MCODE = {
        0x01: BadFlashWrite,
        0x02: FlashFail,
        0x03: VoltageChange,
        0x04: Locked,
        0x05: BadPassword,
        0x06: BadByteWrite,
        0x07: UnknownCmd,
        0x08: Overrun,
    }

    def __init__(self, aTimeout = None):
        """init bsl object, don't connect yet"""
        if aTimeout is None:
            self.timeout = self.DEFAULT_TIMEOUT
        else:
            self.timeout = aTimeout
        self.serialport  = None

        # max data size in txFrame
        self.maxData = self.MAX_DATA_BYTES

        # are we running BSL right now?
        self.inBSL = False

    def calcChecksum(self, data):
        """Calculates a CCITT CRC-16 checksum of data."""
        if not isinstance(data, str):
            data = "".join([chr(x) for x in data])
        crc = 0xffff
        for c in data:
            byte = ord(c)
            ### OVTA implementation
            ### See:
            ###   Efficient High Hamming Distance CRCs for Embedded Networks
            ###   Justin Ray and Philip Koopman
            ###   www.ece.cmu.edu/~koopman/pubs/ray06_crcalgorithms.pdf
            crc  = ((crc >> 8) | (crc << 8)) & 0xffff
            crc ^= byte
            crc ^= (crc & 0xf0) >> 4
            crc ^= (crc & 0x0f) << 12
            crc ^= (crc & 0xff) << 5
        return crc

    ### XXX everything from here up to txFrame was lifted from tos-bsl...
    ### XXX more or less

    def comInit(self, port):
        """
        Tries to open the serial port given and
        initialises the port and variables.
        """
        # Startup-Baudrate: 9600, 8, E, 1, timeout
        Debug.debug(2, "comInit port %s, 9600 8E1, timeout %s", port, self.timeout)
        self.serialport = serial.Serial(
            port,
            9600,
            parity = serial.PARITY_EVEN,
            timeout = self.timeout
        )
        if self.adg715:
            self.setRstTck(1, 1)          # turn off the latch switches
        else:
            # initialize with both high
            self.SetRSTn(1)
            self.SetTEST(1)
        self.serialport.flushInput()
        self.serialport.flushOutput()
        Debug.debug(2, "/comInit")

    def close(self):
        "close the serial port"
        if not self.serialport:
            return
        Debug.debug(2, "close port")
        self.serialport.close()
        self.serialport = None
        Debug.debug(3, "/close")

    def __del__(self):
        self.close()

    def SetDTR(self, level):
        """Control DTR pin"""
        self.serialport.setDTR(not level)

    def SetRTS(self, level):
        """Control RTS pin"""
        self.serialport.setRTS(not level)

    def SetRSTn(self, level):
        """map RSTn (mcu) to RTSn (serial)"""
        Debug.debug(4, "SetRSTn %d"%level)
        if self.invertReset:
            self.SetRTS( not level)
        else:
            self.SetRTS(level)

    def SetTEST(self, level):
        """map TEST (mcu) to DTRn (serial)"""
        Debug.debug(4, "SetTEST %d"%level)
        if self.invertTest:
            self.SetDTR(not level)
        else:
            self.SetDTR(level)

    def SetTCK(self, level):
        """map TCK (mcu) to DTRn (serial)"""
        Debug.debug(4, "SetTCK %d"%level)
        if self.invertTCK:
            self.SetDTR(not level)
        else:
            self.SetDTR(level)

    def adg715SetSCL(self, level):
        "adjust ADG715 SCL (I2C clock) pin"
        self.serialport.setRTS(not level)

    def adg715SetSDA(self, level):
        "adjust ADG715 SDA (I2C data) pin"
        self.serialport.setDTR(not level)

    def adg715I2CStart(self):
        """
        get the ADG715's attention.
        start condition p.13 ADG714_715.pdf: sec 1. SDA 1->0 with SCL 1.
        """
        self.adg715SetSDA(1)
        self.adg715SetSCL(1)
        self.adg715SetSDA(0)
        time.sleep(2e-6)       # ensure we don't go too fast

    def adg715I2CStop(self):
        """
        finish an interchange with the ADG715 latch.
        stop condition p.13 ADG714_715.pdf: sec 3. SDA 0->1 with SCL 1.
        """
        self.adg715SetSDA(0)
        self.adg715SetSCL(1)
        self.adg715SetSDA(1)
        time.sleep(2e-6)       # ensure we don't go too fast

    def adg715I2CWriteBit(self, bit):
        """
        write bit to ADG715 p.13 ADG714_715.pdf: sec 2. and figures 4 and 5.
        SDA transition must occur when SCL is low.
        SDA must be stable during high period of SCL.
        bring SCL low again at end of bit.
        ADG715 clock is 400 kHz max (2.5 us cycle time)
        """
        self.adg715SetSCL(0)
        self.adg715SetSDA(bit)  # SDA transition must occur when SCL is low
        time.sleep(2e-6)       # ensure we don't go too fast
        self.adg715SetSCL(1)    # SDA must be stable during high period of SCL
        time.sleep(2e-6)       # ensure we don't go too fast
        self.adg715SetSCL(0)    # bring SCL low again at end of bit.

    def adg715I2CWriteByte(self, byte):
        """
        write byte to ADG715.
        p.13 ADG714_715.pdf: sec 2. 8 data bits plus an ack bit.
        figures 4 and 5: MSB to LSB.
        """
        self.adg715I2CWriteBit( byte & 0x80 ); # figures 4 and 5: MSB to LSB
        self.adg715I2CWriteBit( byte & 0x40 );
        self.adg715I2CWriteBit( byte & 0x20 );
        self.adg715I2CWriteBit( byte & 0x10 );
        self.adg715I2CWriteBit( byte & 0x08 );
        self.adg715I2CWriteBit( byte & 0x04 );
        self.adg715I2CWriteBit( byte & 0x02 );
        self.adg715I2CWriteBit( byte & 0x01 );
        self.adg715I2CWriteBit( 0 );  # "acknowledge"

    ### I2C address byte prefix for ADG715: ADG714_715.pdf p.12 par. 2
    ADG715_PREFIX = 0x90

    ### select based on configuration of A0 and A1 lines as 0x0 through 0x3.
    ### for the SuRF board, A0 and A1 are tied to GND
    ADG715_ADDR   = 0x00

    ### ADG715 read and write
    ADG715_READ  = 0x01
    ADG715_WRITE = 0x00

    ### ADG715 address byte map:
    ###   +---+---+---+---+---+----+----+------+
    ###   | 1 | 0 | 0 | 1 | 0 | A1 | A0 | R/Wn |
    ###   +---+---+---+---+---+----+----+------+
    
    ### ADG715 command byte:
    ADG715_COMMAND = ADG715_PREFIX | (ADG715_ADDR << 1) | ADG715_WRITE

    def adg715I2CWriteLatch(self, latchState):
        """
        set the state of the ADG715 latch.
        get chip's attention, send address, send switch state, disconnect.
        """
        Debug.debug(5, "adg715I2CWriteLatch: %x"%(latchState))
        self.adg715I2CStart()
        self.adg715I2CWriteByte( self.ADG715_COMMAND )
        self.adg715I2CWriteByte( latchState )
        ### latch has now updated...
        self.adg715I2CStop()

    def setRstTck(self, Rst, Tck):
        """
        Set the state of the RST and SBWTCK lines.

        On SuRF:
         - RSTn has pullup and S1 is connected to RSTn
           - S1 open: RSTn high
           - S1 closed: RSTn low
         - SBWTCK has pullup and S2 is connected to SBWTCK
           - S2 open: SBWTCK high
           - S2 closed: SBWTCK low
        """
        Debug.debug(4, "setRstTck: %x %x"%(Rst, Tck))
        latchState = ((Rst and 1 or 0)  |     \
                      (Tck and 2 or 0)) ^ 0x3
        self.adg715I2CWriteLatch(latchState)


    def bslReset(self, invokeBSL=0):
        """
         BSL entry sequence on cc430 JTAG pins
         rst !s1: 0 0 0 0 1 1
         tck !s2: 0 1 0 1 0 1
           s2|s1: 3 1 3 1 2 0

        BSL exit sequence on cc430 JTAG pins
        Per erratum JTAG20 Feb 2010
         rst !s1: 1 1 1 1 1 0 1
         tck !s2: 0 1 0 1 0 0 0
           s2|s1: 2 0 2 0 2 3 2
        """
        if invokeBSL:
            if self.pauseBSLEntry:
                pdb.set_trace()
            Debug.debug(3, "invokeBSL")
            if self.adg715:
                self.setRstTck(0, 0) #looks ok
                self.setRstTck(0, 1) #OK
                self.setRstTck(0, 0) #OK
                self.setRstTck(0, 1) #OK
                self.setRstTck(1, 1) #swapped 
                self.setRstTck(1, 0) 
            else:
                #DC: would love it if I could figure out which step
                #    was the issue
                if not self.dedicatedJTAG:
                    #               #eRT   aRT  ok 
                    #                 --    11      tx/rx= 0
                    self.SetTEST(0) # -0    10  y       
                    self.SetRSTn(0) # 00    00  y   tx/rx= 1 at transition
                    self.SetTEST(1) # 01    01  y
                    self.SetTEST(0) # 00    00  y 
                    self.SetTEST(1) # 01    01  y
                    self.SetTEST(0) # 00    00  y 
                    self.SetTEST(1) # 01    01  y
                    self.SetRSTn(1) # 11    11  y   (might have been 10 once?)
                    self.SetTEST(0) # 10    10  Y
                    ##DC: tos-bsl says that this should be left high for power
                    ## however! when reprogramming a mote that is
                    ## spamming the serial port, puting TEST high
                    ## seems to cause it to not enter BSL.
                    #self.SetTEST(1) #11 - all right
                else: 
                    self.SetTCK(1)
                    self.SetRSTn(1)
                    self.SetRSTn(0)
                    self.SetTCK(0)
                    self.SetTCK(1)
                    self.SetTCK(0)
                    self.SetRSTn(1)
                    self.SetTCK(1)
            self.inBSL = True
            Debug.debug(3, "/invokeBSL")
        else:
            Debug.debug(3, "reset device")
            if self.adg715:
                if self.errataJTAG20Resolved:
                    raise BSLException, "Standard reset not implemented with ADG715"
                else:
                    self.setRstTck(1, 0)
                    self.setRstTck(1, 1)
                    self.setRstTck(1, 0)
                    self.setRstTck(1, 1)
                    self.setRstTck(1, 0)
                    self.setRstTck(0, 0)
                    self.setRstTck(1, 0)
            else:
                if self.errataJTAG20Resolved or not self.inBSL:
                    Debug.debug(1, "standard reset")
                    self.SetTCK(0)
                    self.SetRSTn(0)
                    self.SetRSTn(1)
                    self.SetTCK(1)
                else:
                    Debug.debug(1, "BSL exit reset")
                    self.SetRSTn(1) #10
                    self.SetTEST(1) #11
                    self.SetTEST(0) #10
                    self.SetTEST(1) #11
                    self.SetTEST(0) #10
                    self.SetRSTn(0) #00
                    #release RST pin so it can start
                    self.SetRSTn(1)
                    #DC: tos-bsl says that this should be left high for power
                    #    see above note for why we ignore this.
                    #self.SetTEST(1)
            self.inBSL = False
            Debug.debug(3, "/reset device")
        # why is this needed? looks like sometimes BSL just randomly
        # exits and mote resumes operation
        # but if this pause isn't here, it seems to fail
        time.sleep(0.25)              # chill out
        self.serialport.flushInput()  # clear buffers

    def txFrame(self, data, doResp=True):
        "send data to BSL"
        if not isinstance(data, str):
            data = "".join([chr(x) for x in data])
        n = len(data)
        assert n <= self.MAX_PI_SIZE
        s = self.calcChecksum(data)
        f = chr(0x80) + chr(n & 0xff) + chr(n >> 8) + \
            data + \
            chr(s & 0xff) + chr(s >> 8)
        Debug.debug(3, "txFrame %s", hexl(f))
        self.serialport.write(f)
        self.serialport.flushOutput()
        if not doResp:
            Debug.debug(3, "/txFrame !doResp")
            return
        resp = self.serialport.read(1)
        if not resp:
            raise BSLTimeout
        else:
            resp = ord(resp)
            if resp:
                klass = self.XCODE.get(resp, BadResponse)
                Debug.debug(3, "/txFrame resp %02x %s", resp, klass.__name__)
                raise klass, resp
            else:
                Debug.debug(3, "/txFrame ACK")

    def rxFrame(self):
        "get response from BSL"
        h = [ord(x) for x in self.serialport.read(3)]
        if len(h) != 3:
            raise BSLTimeout
        Debug.debug(3, "rxFrame Head %s", hexl(h))
        if h[0] != 0x80:
            raise BadRespHdr, h[0]
        n = (h[2] << 8) | h[1]
        if not n:
            raise BadRespLen
        p = self.serialport.read(n)
        Debug.debug(3, "rxFrame Data %d: %s", n, hexl(p))
        if len(p) != n:
            raise BadRespLen
        s = [ord(x) for x in self.serialport.read(2)]
        if len(s) != 2:
            raise BadRespSum
        s = (s[1] << 8) | s[0]
        Debug.debug(3, "rxFrame Sum %04x", s)
        if s != self.calcChecksum(p):
            raise BadRespSum
        c = ord(p[0])
        if c == 0x3a:
             p = p[1:]
             Debug.debug(3, "/rxFrame resp %s", hexl(p))
        elif c == 0x3b:
            if len(p) != 2:
                raise GarbledResp, p
            c = ord(p[1])
            if c:
                klass = self.MCODE.get(c, BadMessage)
                Debug.debug(3, "/rxFrame Msg %02x %s", c, klass.__name__)
                raise klass
            else:
                Debug.debug(3, "/rxFrame Msg SUCCESS")
                return
        else:
            raise BadRespCode, c
        return p
