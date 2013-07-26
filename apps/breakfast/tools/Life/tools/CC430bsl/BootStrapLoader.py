import time

from tools.CC430bsl.BSL import BSL
from tools.CC430bsl.Debug import Debug
from tools.CC430bsl.BSLExceptions import *
from tools.CC430bsl.Progress import Progress

class BootStrapLoader(BSL):
    """higher level Bootstrap Loader functions."""

    def __init__(self, *rest, **kw):
        BSL.__init__(self, *rest, **kw)
        self.byteCtr = 0
        self.data    = None
        self.speed   = 9600

    def programBlk(self, addr, blkout):
        Debug.debug(1, "Program starting at 0x%04x, %i bytes ..." % \
              (addr, len(blkout)))
        self.rxData(addr, blkout)
        Progress.update(self.byteCtr)

    # segments:
    # list of tuples or lists:
    # segments = [ (addr1, [d0,d1,d2,...]), (addr2, [e0,e1,e2,...])]
    def programData(self, segments):
        """program data"""
        bgn = time.time()
        for seg in segments:
            currentAddr = seg.startaddress
            pstart = 0
            while pstart < len(seg.data):
                length = self.maxData
                if pstart+length > len(seg.data):
                    length = len(seg.data) - pstart
                self.programBlk(currentAddr, seg.data[pstart:pstart+length])
                pstart = pstart + length
                currentAddr = currentAddr + length
                self.byteCtr = self.byteCtr + length # total sum
        self.progTime = time.time() - bgn

    def uploadData(self, startaddress, size, wait=0):
        """upload a datablock"""
        Debug.debug(2, "uploadData")
        data = ''
        pstart = 0
        while pstart<size:
            length = self.maxData
            if pstart+length > size:
                length = size - pstart
            data  += self.txData(pstart + startaddress, length)
            pstart = pstart + length
        return data

    #-----------------------------------------------------------------

    def actionMassErase(self, info=""):
        "erase program flash"
        for i in xrange(5):
            if i:
                Debug.debug(1, "Retrying...")
            try:
                self.massErase()
                if len(info) > 0:
                    self.txPassword(None)
                    self.eraseInfo(info)
            except BSLTimeout:
                time.sleep(0.1)
                self.actionStartBSL()
                time.sleep(0.1)
            else:
                return
        raise BSLTimeout

    def _actionStartBSL(self):
        "fire up BSL, adjust baud rate"
        self.bslReset(True)
        if self.speed is not None:
            if self.speed:
                self.actionChangeBaudrate(self.speed)
            else:
                self.setMaxBaud()
            time.sleep(0.010)

    def actionStartBSL(self):
        "fire up BSL"
        for i in xrange(self.bslRetries):
            Debug.debug(1, "try #%d"%i)
            if i:
                Debug.debug(1, "standard reset")
                self.inBSL = False
                self.bslReset()
            try:
                Debug.debug(1, "starting BSL")
                self._actionStartBSL()
            except BSLTimeout:
                Debug.debug(4, "BSLTimeout, try again")
                #port = self.serialport.port
                #self.close()
                #self.comInit(port)
                pass
            else:
                return
            time.sleep(0.1)
        raise BSLTimeout

    def actionChangeBaudrate(self, baudrate=9600):
        self.setBaud(baudrate)

    def actionTxPassword(self):
        "send BSL password"
        self.txPassword(self.passwd)

    def actionProgram(self):
        """program data into flash memory."""
        if self.data is not None:
            Debug.debug(0, "Program ...")
            self.programData(self.data)
            Debug.debug(0, "%i bytes programmed in %.1fsec, %dbps" % \
                  (self.byteCtr,
                   self.progTime,
                   self.byteCtr * 8.0 / (self.progTime or 1e-6)))
        else:
            raise BSLException, "programming without data not possible"

    def actionReset(self):
        "reset MCU"
        Debug.debug(0, "Reset device")
        self.bslReset()

    def actionRun(self, address):
        "jump to address"
        self.loadPC(address)

    def actionReadBSLVersion(self):
        self.txBslVersion()