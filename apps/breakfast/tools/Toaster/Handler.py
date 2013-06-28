
from CC430bsl import CC430bsl
from CC430bsl.Progress import Progress
import Queue
from Bacon import Bacon
from Toast import Toast
from ToastSampling import ToastSampling
from BreakfastError import *
from Dispatcher import Dispatcher 


import time
from threading import Thread

class CleanUpThread(Thread):
    def __init__(self, handler):
        Thread.__init__(self)
        self.handler = handler

    def run(self):
        print "cleanup"
        Dispatcher.stopAll()
        self.handler.publicDisconnect()
        self.notbusy()

        #input = "-S 115200 -c %s -r" % self.currentPort
        #
        #cc430 = CC430bsl.CC430bsl(input, self.resetDone)
        #cc430.start()    

class ToasterThread(Thread):
    def __init__(self, handler):
        Thread.__init__(self)
        self.handler = handler

    def run(self):
        print "autotoast"
        self.handler.comFrame.disconnect()
        time.sleep(1)
        self.handler.program("toaster", self.handler.currentPort, self.handler.programToasterDone)

class Handler(object):

    def __init__(self, root):
        self.bacon = None
        self.toast = None
        self.autoToast = False
        self.root = root
        self.currentProgress = 0

    def busy(self):
        self.root.config(cursor="watch")

    def notbusy(self):
        self.root.config(cursor="")

    def addComFrame(self, com):
        self.comFrame = com

    def addBaconFrame(self, bacon):
        self.baconFrame = bacon

    def addToastFrame(self, toast):
        self.toastFrame = toast

    def addGraphFrame(self, graph):
        self.graphFrame = graph

    def addAdcFrame(self, adc):
        self.adcFrame = adc

    def connect(self, port):
        self.currentPort = port
        input = "-S 115200 -c %s -r" % self.currentPort
        
        cc430 = CC430bsl.CC430bsl(input, self.resetDone)
        cc430.start()

    def resetDone(self, result):
        time.sleep(1)
        self.bacon = Bacon('serial@%s:115200' % self.currentPort, self.signalError)
        self.toast = Toast('serial@%s:115200' % self.currentPort)
        
        self.baconFrame.connectSignal(True)
        
        if self.autoToast:
            self.autoToast = False
            toaster = ToasterThread(self)
            toaster.start()
        else:
            self.notbusy()

    def programToaster(self):
        self.autoToast = True

    def programToasterDone(self, status):
        self.comFrame.connect()
        

    def signalError(self):
        #print "event handler"
        #Dispatcher.stopAll()
        #self.publicDisconnect()
        #self.publicConnect()
        self.busy()
        cleanup = CleanUpThread(self)
        cleanup.start()

        #input = "-S 115200 -c %s -r" % self.currentPort
        #
        #cc430 = CC430bsl.CC430bsl(input, self.resetDone)
        #cc430.start()    

    def disconnect(self):        
        try:
            self.toast.powerOff()
        except:
            pass
        try:
            self.toast.stop()
        except:
            pass
        try:
            self.bacon.stop()
        except:
            pass
        
        # order is important
        self.toastFrame.connectSignal(False)
        self.graphFrame.connectSignal(False)
        self.baconFrame.connectSignal(False)
        self.adcFrame.connectSignal(False)

    #
    # Bacon
    #
    def getMfrID(self):
        mfr = self.bacon.readMfrID()
        mfrStr = ""
        for i in mfr:
            mfrStr += "%02X" % i
        return mfrStr

    def getBaconADCSettings(self):
        adc = self.bacon.readAdcC()
        
        adcList = []
        for i in range(0,16,2):
            adcList.append((adc[i+1] << 8) + adc[i])

        for i in range(18,24,2):
            adcList.append((adc[i+1] << 8) + adc[i])

        return adcList

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
        self.powerCycle()

        try:
            self.toast.readVersion()
        except TagNotFoundError:
            try:
                print "New Toast"
                self.toast.writeVersion(0)
                self.powerCycle()
                self.toast.deleteTLVEntry(Toast.TAG_DCO_30)
                adc = self.toast.readAdcConstants()
                self.toast.writeAdcConstants(adc)
            except:
                pass
        except:
            pass


    def powerCycle(self):
        self.toast.powerOff()
        time.sleep(1)
        self.toast.powerOn()
        self.toast.discover()

    def resetToast(self):
        try:
            self.toast.deleteTLVEntry(Toast.TAG_TOAST_ASSIGNMENTS)
        except TagNotFoundError:
            pass
        
        try:
            self.toast.deleteTLVEntry(Toast.TAG_GLOBAL_ID)
        except TagNotFoundError:
            pass
            
        try:
            self.toast.deleteTLVEntry(Toast.TAG_DCO_30)
        except TagNotFoundError:
            pass
            
        try:
            self.toast.deleteTLVEntry(Toast.TAG_DCO_CUSTOM)
        except TagNotFoundError:
            pass
            
        self.powerCycle()
        
        adc = self.toast.readAdcConstants()
        self.toast.writeAdcConstants(adc)



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
            
        self.toast.writeBarcode(output)

    def getAssignments(self):
        return self.toast.readAssignments()

    def setAssignments(self, assignments):
        #try:
        #    self.toast.deleteTLVEntry(Toast.TAG_TOAST_ASSIGNMENTS)
        #except TagNotFoundError:
        #    pass
        self.toast.writeAssignments(assignments)
    
    def getToastADCSettings(self):
        adc = self.toast.readTLVEntry(Toast.TAG_ADC12_1)
        
        adcList = []
        for i in range(0,16,2):
            adcList.append((adc[i+1] << 8) + adc[i])
            
        return adcList

    def getDCOSettings(self):
        dco = self.toast.readTLVEntry(Toast.TAG_DCO_CUSTOM)
        dcoStr = "%02X%02X" % (dco[0], dco[1])
        
        return dcoStr

    #
    # Sensor
    #
    def startSampling(self, sensors):
        self.sampleThread = ToastSampling(self, sensors)
        self.sampleThread.start()
        
        self.baconFrame.disableUI()
        self.adcFrame.disableUI()
        self.graphFrame.sampleSignal(True)

    def stopSampling(self):
        self.sampleThread.stop()
        
        self.baconFrame.enableUI()
        self.adcFrame.enableUI()
        self.graphFrame.sampleSignal(False)


    def readSensor(self, channel, sensorImpedance=10000, warmUpMs = 10, 
      sref = Toast.REFERENCE_VREFplus_AVss, ref2_5v = True, samplePeriod32k = 0):
      
      return self.toast.readSensor(channel, sensorImpedance, warmUpMs, 
      sref, ref2_5v, samplePeriod32k)

    def getReadings(self):
        return self.sampleThread.queue.get(False)

