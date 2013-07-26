from tools.CC430bsl.LowLevel import LowLevel
from tools.CC430bsl.Debug import Debug
from tools.CC430bsl.BSLExceptions import *
from tools.CC430bsl.hexl import hexl

class BSL(LowLevel):
    "Implements (most) BSL commands using txFrame and rxFrame"

    BAUD = (
        (115200, 0x06),
        (57600,  0x05),
        (38400,  0x04),
        (19200,  0x03),
        (9600,   0x02),
    )
    
    #added to identify when info a is being written
    INFO_A_START = 0x001980
    INFO_A_END   = 0x0019FF

    CMD_BAUD_RATE     = 0x52 # - Implemented
    CMD_RX_DATA       = 0x10 # - Implemented
    CMD_RX_DATA_FAST  = 0x1b # - Implemented
    CMD_RX_PASSWD     = 0x11 # - Implemented
    CMD_ERASE_SEGMENT = 0x12 # - Implemented
    CMD_UNLOCK_INFO   = 0x13 # - Implemented
    CMD_MASS_ERASE    = 0x15 # - Implemented
    CMD_CRC_CHECK     = 0x16 # x Won't implement
    CMD_LOAD_PC       = 0x17 # - Implemented, RETA doesn't seem to return...
    CMD_TX_DATA       = 0x18 # - Implemented
    CMD_BSL_VERSION   = 0x19 # - Implemented
    CMD_TX_BUF_SIZE   = 0x1a # ? Doesn't work


    def __init__(self, *rest, **kw):
        LowLevel.__init__(self, *rest, **kw)
        self.fastrx = False
        self.passwd = None

    def setBaud(self, rate=None):
        "set BSL and serial port baud rate"
        assert self.inBSL
        if rate is None:
            return self.setMaxBaud()
        code = [x[1] for x in self.BAUD if x[0] == rate]
        if not code:
            raise RuntimeError, "unsupported baud rate requested"
        code = code[0]
        Debug.debug(2, "setBaud %02x %d", code, rate)
        try:
            self.txFrame([self.CMD_BAUD_RATE, code])
        except BadBaudRate:
            raise
        else:
            self.serialport.setBaudrate(rate)
            Debug.debug(0, "Baud rate set to %d", rate)
        Debug.debug(3, "/setBaud")

    def setMaxBaud(self):
        "select max baud rate MCU will support"
        # XXX this seems to work on SuRF F6137
        for (rate, code) in self.BAUD:
            try:
                self.setBaud(rate)
            except BadBaudRate:
                pass
            else:
                self.serialport.setBaudrate(rate)
                return rate

    def massErase(self):
        "erase program flash"
        assert self.inBSL
        Debug.debug(2, "massErase")
        self.txFrame([self.CMD_MASS_ERASE])
        assert self.rxFrame() is None
        Debug.debug(3, "/massErase")

    def txPassword(self, passwd):
        "send BSL password"
        # XXX needs test, works after massErase
        assert self.inBSL
        #default password is [0xff]*32
        passwd = passwd or self.passwd or ([0xff] * 32)
        Debug.debug(2, "txPassword %s", hexl(passwd))
        if not isinstance(passwd, str):
            passwd = "".join([chr(x) for x in passwd])
        self.txFrame(chr(self.CMD_RX_PASSWD) + passwd)
        assert self.rxFrame() is None
        Debug.debug(3, "/txPassword")

    def txBslVersion(self):
        "print out BSL version info"
        assert self.inBSL
        Debug.debug(2, "txBslVersion")
        try:
            self.txFrame(chr(self.CMD_BSL_VERSION))
            resp = self.rxFrame()
        except BSLTimeout:
            raise 
        except BSLException:
            resp = ""
        if len(resp) != 4:
            Debug.debug(0, "BSL Version garbled or unimplemented, continuing anyway")
        else:
            vid, ver, api, pi = [ord(x) for x in resp]
            vid = "Vendor %s(%02x)" % (vid and "Unknown" or "TI", vid)
            ver = "Interp %02x" % ver
            api = "API %02x%s" % (api, api & 0x80 and " Limited" or "")
            if pi < 0x20:
                pi = "PI TA_UART(%02x)" % pi
            elif pi < 0x50:
                pi = "PI USB(%02x)" % pi
            elif pi < 0x70:
                pi = "PI USCI_UART(%02x)" % pi
            else:
                pi = "PI Unknown(%02x)" % pi
            Debug.debug(0, "BSL Version: %s, %s, %s, %s", vid, ver, api, pi)
        Debug.debug(3, "/txBslVersion")

    def txData(self, addr, length):
        "get data from MCU memory"
        assert self.inBSL
        assert 0x000000 <= addr <= 0xffffff
        assert 0x0000 < length <= 0xffff
        ### CMD_TX_BUF_SIZE doesn't seem to work
        ### in practice, 260 seems to be the limit
        ### stick to 0x100 and lower
        assert 0 < length <= 0x100
        Debug.debug(2, "txData %04x @ %06x", length, addr)
        self.txFrame([self.CMD_TX_DATA,
                      (addr >>  0) & 0xff,
                      (addr >>  8) & 0xff,
                      (addr >> 16) & 0xff,
                      (length >> 0) & 0xff,
                      (length >> 8) & 0xff])
        ret = self.rxFrame()
        if len(ret) != length:
            raise GarbledResp, (len(ret), ret)
        Debug.debug(3, "txData resp %s", hexl(ret))
        Debug.debug(3, "/txData")
        return ret

    def _rxData(self, addr, data, slow):
        "write data into MCU memory"
        assert self.inBSL
        assert 0x000000 <= addr <= 0xffffff
        assert isinstance(data, str) and data
        ### CMD_TX_BUF_SIZE doesn't seem to work
        ### in practice, 260 seems to be the limit
        ### stick to 0x100 and lower
        assert 0 < len(data) <= 0x100
        Debug.debug(2, "rxData%s %d @ %06x: %s",
              (not slow) and " Fast" or "", len(data), addr, hexl(data))

        #if this is writing to INFO A, need to lock/unlock
        #TODO: not sure what state things are left in if the toggle works, but the data isn't received by the mcu properly
        usingInfoA = ( self.INFO_A_START <= addr <= self.INFO_A_END) or ( self.INFO_A_START <= addr+len(data) <= self.INFO_A_END)
        if usingInfoA:
            self._toggleLOCKA()
        head = "".join([chr(slow and self.CMD_RX_DATA or self.CMD_RX_DATA_FAST),
                        chr((addr >>  0) & 0xff),
                        chr((addr >>  8) & 0xff),
                        chr((addr >> 16) & 0xff)])
        self.txFrame(head + data)
        if slow:
            assert self.rxFrame() is None
        if usingInfoA:
            self._toggleLOCKA()
        Debug.debug(3, "/rxData")

    def rxData(self, addr, data):
        "program with verify"
        self._rxData(addr, data, not self.fastrx)

    def eraseSegment(self, addr):
        "erase a segment by address"
        assert self.inBSL
        assert 0x000000 <= addr <= 0xffffff
        Debug.debug(2, "eraseSegment %06x", addr)
        self.txFrame([self.CMD_ERASE_SEGMENT,
                      (addr >>  0) & 0xff,
                      (addr >>  8) & 0xff,
                      (addr >> 16) & 0xff])
        assert self.rxFrame() is None
        Debug.debug(3, "/eraseSegment")

    def _toggleLOCKA(self):
        "toggle the LOCKA bit"
        Debug.debug(3, "toggleLOCKA")
        self.txFrame(chr(self.CMD_UNLOCK_INFO))
        assert self.rxFrame() is None
        Debug.debug(3, "/toggleLOCKA")

    def _eraseInfoA(self):
        "erase info segment A"
        assert self.inBSL
        Debug.debug(3, "eraseInfoA")
        ### XXX toggling LOCKA doesn't seem to matter??
        self._toggleLOCKA()
        self.eraseSegment(self.INFO_A_START)
        self._toggleLOCKA()
        Debug.debug(3, "/eraseInfoA")

    ### XXX this probably only works for:
    ### XXX   F5133, F5135, F6125, F6135, F6126, F5137, F6127, and F6137
    INFO_ADDRS = {
        "a": None,     # use eraseInfoA() for this one
        "b": 0x001900,
        "c": 0x001880,
        "d": 0x001800,
    }

    def eraseInfo(self, which="abcd"):
        "erase some/all of info segments A-D"
        assert self.inBSL
        assert isinstance(which, str) and which and len(which) <= 4
        d = { }
        for seg in which.lower():
            assert seg in self.INFO_ADDRS
            d.setdefault(seg)
        d = d.keys()
        d.sort()
        Debug.debug(2, "eraseInfo segs=%s", "".join(d))
        for seg in d:
            addr = self.INFO_ADDRS[seg]
            if addr is None:
                self._eraseInfoA()
            else:
                Debug.debug(2, "Erasing INFO %s", seg)
                self.eraseSegment(addr)
        Debug.debug(3, "/eraseInfo")

    def loadPC(self, addr, expectReturn=False):
        "jump to location"
        assert self.inBSL
        assert 0x000000 <= addr <= 0xffffff
        assert not (addr & 1)
        Debug.debug(2, "loadPC %06x", addr)
        self.txFrame([self.CMD_LOAD_PC,
                      (addr >>  0) & 0xff,
                      (addr >>  8) & 0xff,
                      (addr >> 16) & 0xff])
        ### XXX a RETA doesn't seem to return to BSL?
        ### XXX OK, just break ourself then
        self.inBSL = False
        Debug.debug(3, "/loadPC")
