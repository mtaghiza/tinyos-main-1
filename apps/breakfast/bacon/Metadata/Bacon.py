#!/usr/bin/env python

import time

from Dispatcher import Dispatcher 
from mig import *
from TLV import TLV
from TOS import TOS


class Bacon(object):

    busPower = None

    def __init__(self):
        self.dispatcher = Dispatcher()

    def stop(self):
        self.dispatcher.stop()

    #
    # Bacon commands
    #
    def ping(self):
        """ Send ping message to Bacon. Throws exception if no response.
        """
        msg = PingCmdMsg.PingCmdMsg()
        
        ret = self.dispatcher.send(msg)
        if ret.get_error() != TOS.SUCCESS:
            raise ValueError

    def reset(self):
        """ Reset Bacon node.
        """
        msg = ResetBaconCmdMsg.ResetBaconCmdMsg()        
        
        ret = self.dispatcher.send(msg)
        if ret.get_error() != TOS.SUCCESS:
            raise ValueError
        
        Bacon.busPower = None

    def readIV(self):
        """ Read Interrupt Vector. Used for targeted flash erases.
        """
        msg = ReadIvCmdMsg.ReadIvCmdMsg()
        
        ret = self.dispatcher.send(msg)
        if ret.get_error() != TOS.SUCCESS:
            raise ValueError
        
        return ret.get_iv()
    
    def readMfrID(self):
        """ Read lot, wafer, die information from Bacon ROM
        """
        msg = ReadMfrIdCmdMsg.ReadMfrIdCmdMsg()
        
        ret = self.dispatcher.send(msg)
        if ret.get_error() != TOS.SUCCESS:
            raise ValueError
        
        return ret.get_mfrId()

    #
    # Bacon TLV functions
    #
    def readVersion(self):
        """ Read Bacon TLV version number. Autoincroments on each write.
        """
        msg = ReadBaconVersionCmdMsg.ReadBaconVersionCmdMsg()
        
        ret = self.dispatcher.send(msg)
        if ret.get_error() != TOS.SUCCESS:
            raise ValueError
            
        return ret.get_version()

    #def writeVersion(self, newVersion):
    #    msg = WriteBaconVersionCmdMsg.WriteBaconVersionCmdMsg()        
    #    msg.set_version(newVersion)
    #    
    #    ret = self.dispatcher.send(msg)        
    #    if ret.get_error() != TOS.SUCCESS:
    #        raise ValueError

    def readBarcode(self):
        """ Read unique ID from Bacon TLV region.
        """
        msg = ReadBaconBarcodeIdCmdMsg.ReadBaconBarcodeIdCmdMsg()
        
        ret = self.dispatcher.send(msg)
        if (ret.get_error() != TOS.SUCCESS) or (ret.get_error() != TOS.EINVAL):
            raise ValueError
        
        return ret.get_barcodeId()


    def writeBarcode(self, newBarcode):    
        """ Write unique ID to Bacon TLV region. Requires input array to have 8 elements.
        """
        msg = WriteBaconBarcodeIdCmdMsg.WriteBaconBarcodeIdCmdMsg()
        
        # consistency check on the given array's length
        if len(newBarcode) == msg.totalSize_barcodeId():
            msg.set_barcodeId(newBarcode)
            
            ret = self.dispatcher.send(msg)            
            if ret.get_error() != TOS.SUCCESS:
                raise ValueError
        else:
            raise ValueError

    def readTLV(self):
        """ Read entire TLV.
        """
        msg = ReadBaconTlvCmdMsg.ReadBaconTlvCmdMsg()
        ret = self.dispatcher.send(msg)
        if ret.get_error() != TOS.SUCCESS:
            raise ValueError

        return ret.get_tlvs()

    def writeTLV(self, newTLV):
        """ Write entire TLV. Requires input array to have 128 elements.
        """
        msg = WriteBaconTlvCmdMsg.WriteBaconTlvCmdMsg()
        
        # consistency check on the given array's length
        if len(newTLV) == msg.totalSize_tlvs():
            msg.set_tlvs(newTLV)
            
            ret = self.dispatcher.send(msg)
            if ret.get_error() != TOS.SUCCESS:
                raise ValueError
        else:
            raise ValueError            


    def readTLVEntry(self, tag):
        """ Read entry in TLV with the specified tag.
        """
        msg = ReadBaconTlvEntryCmdMsg.ReadBaconTlvEntryCmdMsg()        
        msg.set_tag(tag)

        ret = self.dispatcher.send(msg)
        if (ret.get_error() != TOS.SUCCESS) and (ret.get_error() != TOS.EINVAL):
            raise ValueError
        
        # the Bacon mote uses different reponse types depending on the tag
        if (tag == TLV.TAG_VERSION):
            return ret.get_version()
        elif (tag == TLV.TAG_GLOBAL_ID):
            return ret.get_barcodeId()
        else:
            return ret.get_data()


    def addTLVEntry(self, tag, data):
        """ Add entry to TLV with the specified tag and array. Length is automatically set.
        """
        msg = AddBaconTlvEntryCmdMsg.AddBaconTlvEntryCmdMsg()
        msg.set_tag(tag)
        msg.set_len(len(data))
        msg.set_data(data)
        
        ret = self.dispatcher.send(msg)
        if ret.get_error() != TOS.SUCCESS:
            raise ValueError
    
    
    def deleteTLVEntry(self, tag):
        """ Delete entry in TLV with the specified tag.
        """
        msg = DeleteBaconTlvEntryCmdMsg.DeleteBaconTlvEntryCmdMsg()
        msg.set_tag(tag)
        
        ret = self.dispatcher.send(msg)
        if ret.get_error() != TOS.SUCCESS:
            raise ValueError

    #
    # Toast commands
    #
    def busPowerOn(self):        
        """ Power on Toast bus.
        """
        if Bacon.busPower != 1:
            # power on bus
            msg = SetBusPowerCmdMsg.SetBusPowerCmdMsg()
            msg.set_powerOn(1)
            
            ret = self.dispatcher.send(msg)
            if ret.get_error() != TOS.SUCCESS:
                raise ValueError
            
            Bacon.busPower = 1

    def busPowerOff(self):
        """ Power off Toast bus.
        """
        if Bacon.busPower != 0:
            # power off bus
            msg = SetBusPowerCmdMsg.SetBusPowerCmdMsg()
            msg.set_powerOn(0)
            
            ret = self.dispatcher.send(msg)
            if ret.get_error() != TOS.SUCCESS:
                raise ValueError
            
            Bacon.busPower = 0

    def getToast(self):
        """ Discover attached Toast boards and return Toast object for manipulation.
        """
        self.busPowerOn()
        msg = ScanBusCmdMsg.ScanBusCmdMsg()
        ret = self.dispatcher.send(msg)
        
        if ret.get_error() == 0 and ret.get_numFound() > 0:
            print 'Found', ret.get_numFound(), 'toasts'


if __name__ == '__main__':
    
    bacon = Bacon()

    time.sleep(2)

#    print bacon.writeVersion(0x42)
#    print bacon.writeBarcode([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])

    #print bacon.readVersion()
    #print bacon.readIV()
    #print bacon.readMfrID()
    
    print bacon.readTLV()
    
    #print bacon.deleteTLVEntry(TLV.TAG_GLOBAL_ID), TLV.TAG_GLOBAL_ID
    #print bacon.addTLVEntry(TLV.TAG_GLOBAL_ID, [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])

    print bacon.readTLVEntry(TLV.TAG_VERSION), TLV.TAG_VERSION
    print bacon.readTLVEntry(TLV.TAG_GLOBAL_ID), TLV.TAG_GLOBAL_ID
    
    #try:
    #    print 'barcode: ', bacon.readBarcode()
    #except:
    #    print 'No barcode recorded'
        
#    print bacon.reset()    
#    print bacon.ping()
#    print bacon.busPowerOn()    
#    time.sleep(1)
#    print bacon.getToast()
#    print bacon.busPowerOff()    
    
    
    bacon.stop()