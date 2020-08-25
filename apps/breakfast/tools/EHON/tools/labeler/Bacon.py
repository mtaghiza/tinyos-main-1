#!/usr/bin/env python

# Copyright (c) 2014 Johns Hopkins University
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# - Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
# - Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the
#   distribution.
# - Neither the name of the copyright holders nor the names of
#   its contributors may be used to endorse or promote products derived
#   from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
# THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.


import time

from tools.labeler.Dispatcher import Dispatcher 
from tools.labeler.TOS import TOS
from tools.labeler.BreakfastError import *

from tools.mig import *


class Bacon(object):

    TAG_DCO_30  = 0x01              # Toast factory clock calibration, delete
    TAG_VERSION = 0x02              # Required by storage utility
    TAG_DCO_CUSTOM = 0x03           # Toast custom clock calibration, automatically generated on boot
    TAG_GLOBAL_ID = 0x04            # global barcode ID for toast/bacon devices
    TAG_TOAST_ASSIGNMENTS = 0x05    # Toast sensor assignments
    TAG_ADC12_1 = 0x08              # Toast ADC Calibration constants

    def __init__(self, motestring='serial@/dev/ttyUSB0:115200', signalError=lambda : None):
        self.dispatcher = Dispatcher(motestring, signalError)

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
            raise NoResponseError

    def reset(self):
        """ Reset Bacon node.
        """
        msg = ResetBaconCmdMsg.ResetBaconCmdMsg()        
        
        ret = self.dispatcher.send(msg)
        if ret.get_error() != TOS.SUCCESS:
            raise UnexpectedResponseError

    def readIV(self):
        """ Read Interrupt Vector. Used for targeted flash erases.
        """
        msg = ReadIvCmdMsg.ReadIvCmdMsg()
        
        ret = self.dispatcher.send(msg)
        if ret.get_error() != TOS.SUCCESS:
            raise UnexpectedResponseError
        
        return ret.get_iv()
    
    def readMfrID(self):
        """ Read lot, wafer, die information from Bacon ROM
        """
        msg = ReadMfrIdCmdMsg.ReadMfrIdCmdMsg()
        
        ret = self.dispatcher.send(msg)
        if ret.get_error() != TOS.SUCCESS:
            raise UnexpectedResponseError
        
        return ret.get_mfrId()
    
    def readAdcC(self):
        """ Read ADC calibration constants from Bacon ROM
        """
        msg = ReadAdcCCmdMsg.ReadAdcCCmdMsg()
        
        ret = self.dispatcher.send(msg)
        if ret.get_error() != TOS.SUCCESS:
            raise UnexpectedResponseError
        
        return ret.get_adc()
    #
    # Bacon TLV functions
    #
    def readVersion(self):
        """ Read Bacon TLV version number. Autoincroments on each write.
        """
        msg = ReadBaconVersionCmdMsg.ReadBaconVersionCmdMsg()
        
        ret = self.dispatcher.send(msg)
        if ret.get_error() != TOS.SUCCESS:
            raise UnexpectedResponseError
            
        return ret.get_version()


    def readBarcode(self):
        """ Read unique ID from Bacon TLV region.
        """
        msg = ReadBaconBarcodeIdCmdMsg.ReadBaconBarcodeIdCmdMsg()
        
        ret = self.dispatcher.send(msg)
        if (ret.get_error() == TOS.EINVAL):
            raise TagNotFoundError
        elif (ret.get_error() != TOS.SUCCESS):
            raise UnexpectedResponseError
        
        return ret.get_barcodeId()


    def writeBarcode(self, newBarcode):    
        """ Write unique ID to Bacon TLV region. Requires input array to have 8 elements.
        """
        msg = WriteBaconBarcodeIdCmdMsg.WriteBaconBarcodeIdCmdMsg()        

        # consistency check on the given array's length
        if len(newBarcode) != msg.totalSize_barcodeId():
            raise InvalidInputError
        
        msg.set_barcodeId(newBarcode)
        
        ret = self.dispatcher.send(msg)            
        if ret.get_error() != TOS.SUCCESS:
            raise UnexpectedResponseError

    #
    # Direct TLV commands
    #
    def initTLV(self, newVersion):
        """ Initializes empty TLV by writing new version number.
        """
        msg = WriteBaconVersionCmdMsg.WriteBaconVersionCmdMsg()        
        msg.set_version(newVersion)
        
        ret = self.dispatcher.send(msg)        
        if ret.get_error() != TOS.SUCCESS:
            raise ValueError


    def readTLV(self):
        """ Read entire TLV.
        """
        msg = ReadBaconTlvCmdMsg.ReadBaconTlvCmdMsg()
        ret = self.dispatcher.send(msg)
        if ret.get_error() != TOS.SUCCESS:
            raise UnexpectedResponseError
        
        return ret.get_tlvs()


    def writeTLV(self, newTLV):
        """ Write entire TLV. Requires input array to have 128 elements.
        """        
        msg = WriteBaconTlvCmdMsg.WriteBaconTlvCmdMsg()

        # consistency check on the given array's length
        if len(newTLV) != msg.totalSize_tlvs():
            raise InvalidInputError
        
        msg.set_tlvs(newTLV)
        
        ret = self.dispatcher.send(msg)
        if ret.get_error() != TOS.SUCCESS:
            raise UnexpectedResponseError


    def readTLVEntry(self, tag):
        """ Read entry in TLV with the specified tag.
        """
        msg = ReadBaconTlvEntryCmdMsg.ReadBaconTlvEntryCmdMsg()        
        msg.set_tag(tag)

        ret = self.dispatcher.send(msg)
        if (ret.get_error() == TOS.EINVAL):
            raise TagNotFoundError
        elif (ret.get_error() != TOS.SUCCESS):
            raise UnexpectedResponseError
        
        # the Bacon mote uses different reponse types depending on the tag
        if (tag == Bacon.TAG_VERSION):
            return ret.get_version()
        elif (tag == Bacon.TAG_GLOBAL_ID):
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
            raise UnexpectedResponseError
    
    
    def deleteTLVEntry(self, tag):
        """ Delete entry in TLV with the specified tag.
        """
        msg = DeleteBaconTlvEntryCmdMsg.DeleteBaconTlvEntryCmdMsg()
        msg.set_tag(tag)
        
        ret = self.dispatcher.send(msg)
        if ret.get_error() != TOS.SUCCESS:
            raise UnexpectedResponseError


if __name__ == '__main__':

    import os
    if os.name == 'nt': 
        bacon = Bacon('serial@COM26:115200')
    else:
        bacon = Bacon('serial@/dev/ttyUSB0:115200')
        

    #time.sleep(2)

#    print bacon.writeVersion(0x42)
    #print bacon.writeBarcode([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x09])

    #print bacon.readVersion()
    #print bacon.readIV()
    #print bacon.readAdcC()
    
    print bacon.readTLV()
    
    #print bacon.deleteTLVEntry(Bacon.TAG_GLOBAL_ID), Bacon.TAG_GLOBAL_ID
    #print bacon.addTLVEntry(Bacon.TAG_GLOBAL_ID, [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])

    #print bacon.readTLVEntry(Bacon.TAG_VERSION)
    #print bacon.readTLVEntry(Bacon.TAG_GLOBAL_ID)
    
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
