
from CC430bsl import CC430bsl
from CC430bsl.Progress import Progress
import Queue
from Bacon import Bacon
from Toast import Toast
from BreakfastError import *

import time

class Handler(object):


    def __init__(self):
        self.connectListeners = []
        self.bacon = None
        self.toast = None

    def addConnectListener(self, callMe):
        self.connectListeners.append(callMe)

    def connect(self, port, statusVar):
        self.bacon = Bacon('serial@%s:115200' % port)
        self.toast = Toast('serial@%s:115200' % port)

        for listener in self.connectListeners:
            listener(True)
        
    
    def disconnect(self, statusVar):        
        for listener in self.connectListeners:
            listener(False)
            
        try:
            self.toast.powerOff()
        except:
            pass
        self.toast.stop()
        self.bacon.stop()

    #
    # Bacon
    #
    def getMfrID(self):
        mfr = self.bacon.readMfrID()
        mfrStr = ""
        for i in mfr:
            mfrStr += "%02X" % i
        return mfrStr

    def getBaconBarcode(self):
        barcode = self.bacon.readBarcode()
        
        barcodeStr = ""
        for i in barcode:
            barcodeStr += "%02X" % i
            
        return barcodeStr

    def setBaconBarcode(self, barcodeStr):

        # format barcode into int array, this also validates input
        barcode = int(barcodeStr, 16)
        output = []
        for i in range(0,8):
            output.append((barcode >> ((7-i)*8)) & 0xFF)
        
        # remove all barcode entries in TLV
        try:
            while(True):
                self.bacon.deleteTLVEntry(Bacon.TAG_GLOBAL_ID)
        except:
            pass
            
        self.bacon.writeBarcode(output)

    def program(self, name, port, callMe):
        print name, port
        self.currentProgress = 0
        input = "-S 115200 -c %s -r -e -I -p %s.ihex" % (port, name)
        
        cc430 = CC430bsl.CC430bsl(input, callMe)
        cc430.start()

    def programProgress(self):
        try:
            while(True):
                self.currentProgress = Progress.wait(False)
        except Queue.Empty:
            pass
        return self.currentProgress

    #
    # Toast
    #
    def connectToast(self):
        
        self.toast.powerOff()
        time.sleep(1)
        self.toast.powerOn()
        self.toast.discover()    

    def getToastBarcode(self):
        barcode = self.toast.readBarcode()
        
        barcodeStr = ""
        for i in barcode:
            barcodeStr += "%02X" % i
        
        return barcodeStr

    def setToastBarcode(self, barcodeStr):
        # format barcode into int array, this also validates input
        barcode = int(barcodeStr, 16)
        output = []
        for i in range(0,8):
            output.append((barcode >> ((7-i)*8)) & 0xFF)
        
        # remove all barcode entries in TLV
        try:
            while(True):
                self.toast.deleteTLVEntry(Toast.TAG_GLOBAL_ID)
        except:
            pass
            
        self.toast.writeBarcode(output)

    def getAssignments(self):
        return self.toast.readAssignments()

    def setAssignments(self, assignments):
    
        # remove all barcode entries in TLV
        try:
            while(True):
                self.toast.deleteTLVEntry(Toast.TAG_TOAST_ASSIGNMENTS)
        except:
            pass
               
        self.toast.writeAssignments(assignments)
    
    def getADCSettings(self):
        adc = self.toast.readTLVEntry(Toast.TAG_ADC12_1)
        
        adcStr = ""
        for i in range(0,16):
            adcStr += "%02X" % adc[i]
            
        return adcStr

    def getDCOSettings(self):
        dco = self.toast.readTLVEntry(Toast.TAG_DCO_CUSTOM)
        dcoStr = "%02X%02X" % (dco[0], dco[1])
        
        return dcoStr

    def updateDCO(self):
        # remove all DCO entries in TLV
        try:
            while(True):
                self.toast.deleteTLVEntry(Toast.TAG_DCO_CUSTOM)
        except:
            pass

        try:
            while(True):
                self.toast.deleteTLVEntry(Toast.TAG_DCO_30)
        except:
            pass

        try:
            while(True):
                self.toast.deleteTLVEntry(Toast.TAG_VERSION)
        except:
            pass

        self.toast.writeVersion(0x01)
        self.toast.powerOff()
        time.sleep(1)
        self.toast.powerOn()
        self.toast.discover()
    