import Queue
import time
import os
from threading import Thread


from tools.CC430bsl.CC430bsl import CC430bsl
from tools.CC430bsl.Progress import Progress
from tools.labeler.Bacon import Bacon
from tools.labeler.Toast import Toast
from tools.labeler.ToastSampling import ToastSampling
from tools.labeler.BreakfastError import *
from tools.labeler.Dispatcher import Dispatcher 

from tools.labeler.Database import Database





class Handler(object):

    def __init__(self, root):
        self.bacon = None
        self.toast = None
        self.autoToast = False
        self.root = root
        self.currentProgress = 0
        self.database = Database()

        self.baconIdStr = ""
        self.mfrStr = ""
        self.baconAdcList = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        
        self.toastIdStr = ""
        self.toastAdcList = [0, 0, 0, 0, 0, 0, 0, 0]
        
        self.cleanup = False
        self.autoToastDone = False
        self.maintenanceLoop()

    def maintenanceLoop(self):
        #print "loop"

        if self.cleanup:
            print "clean up"
            self.cleanup = False
            self.busy()
            Dispatcher.stopAll()
            self.menuFrame.disconnect()
            self.notbusy()
        
        if self.autoToastDone:
            print "auto programming done"
            self.autoToastDone = False
            self.menuFrame.connect()
        
        self.root.after(1000, self.maintenanceLoop)

    def busy(self):
        self.root.config(cursor="watch")

    def notbusy(self):
        self.root.config(cursor="")

    def addMenuFrame(self, menu):
        self.menuFrame = menu

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
        
        cc430 = CC430bsl(input, self.resetDone)
        cc430.start()
        cc430.join()
        
        time.sleep(1)
        
        self.bacon = Bacon('serial@%s:115200' % self.currentPort, self.signalError)
        self.toast = Toast('serial@%s:115200' % self.currentPort)
        
        self.baconFrame.connectSignal(True)
        
        if self.autoToast:
            self.autoToast = False
            self.disconnect()
            time.sleep(1)
            
            toaster_file = os.path.join('tools', 'firmware', 'toaster.ihex')        
            self.program(toaster_file, self.currentPort, self.programToasterDone)
        else:   
            self.notbusy()

    def programToaster(self):
        self.autoToast = True

    def resetDone(self, result):
        pass

    def programToasterDone(self, status):
        self.autoToastDone = True

    def signalError(self):
        self.cleanup = True

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
        self.mfrStr = ""
        for i in mfr:
            self.mfrStr += "%02X" % i
        return self.mfrStr

    def getBaconADCSettings(self):
        adc = self.bacon.readAdcC()
        
        self.baconAdcList = []
        for i in range(0,16,2):
            self.baconAdcList.append((adc[i+1] << 8) + adc[i])

        for i in range(18,24,2):
            self.baconAdcList.append((adc[i+1] << 8) + adc[i])

        return self.baconAdcList

    def getBaconBarcode(self):
        barcode = self.bacon.readBarcode()
        
        self.baconIdStr = ""
        for i in reversed(barcode): # byte array is little endian
            self.baconIdStr += "%02X" % i
            
        return self.baconIdStr

    def setBaconBarcode(self, barcodeStr):
        # format barcode into int array, this also validates input
        barcode = int(barcodeStr, 16)
        output = []
        for i in range(0,8):
            output.append((barcode >> (i*8)) & 0xFF) # byte array is little endian
            
        if output[7] != 0x04: # magic number
            raise TypeError
            
        self.bacon.writeBarcode(output)
        
        # update successful, store in handler
        self.baconIdStr = "%016X" % barcode

    def program(self, name, port, callMe):
        print name, port
        self.currentProgress = 0
        
        input = "-S 115200 -c %s -r -e -I -p %s" % (port, name)        
        cc430 = CC430bsl(input, callMe)
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
                print "New Multiplexer detected"
                self.toast.writeVersion(0)
            except:
                pass
            
            try:
                self.powerCycle()
            except:
                pass
                
            try:
                self.toast.deleteTLVEntry(Toast.TAG_DCO_30)
            except:
                pass
                
            try:
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
        except:
            print "Delete assignments failed"
            pass
        
        try:
            self.toast.deleteTLVEntry(Toast.TAG_GLOBAL_ID)
        except:
            print "Delete ID failed"
            pass
            
        try:
            self.toast.deleteTLVEntry(Toast.TAG_DCO_30)
        except:
            print "Delete DCO failed"
            pass
            
        try:
            self.toast.deleteTLVEntry(Toast.TAG_DCO_CUSTOM)
        except:
            print "Delete custom DCO failed"
            pass
            
        self.powerCycle()
        
        try:
            adc = self.toast.readAdcConstants()
            self.toast.writeAdcConstants(adc)
        except:
            pass


    def getToastBarcode(self):
        barcode = self.toast.readBarcode()
        
        self.toastIdStr = ""
        for i in reversed(barcode): # byte array is little endian
            self.toastIdStr += "%02X" % i
        
        return self.toastIdStr

    def setToastBarcode(self, barcodeStr):
        
        # format barcode into int array, this also validates input
        barcode = int(barcodeStr, 16)
        output = []
        for i in range(0,8):
            output.append((barcode >> (i*8)) & 0xFF) # byte array is little endian
            
        if output[7] != 0x05: # magic number
            raise TypeError
            
        self.toast.writeBarcode(output)
        
        # update successful, store in handler
        self.toastIdStr = "%016X" % barcode

    def getAssignments(self):
        return self.toast.readAssignments()

    def setAssignments(self, assignments):
        #try:
        #    self.toast.deleteTLVEntry(Toast.TAG_TOAST_ASSIGNMENTS)
        #except TagNotFoundError:
        #    pass
        self.toastAssignments = assignments
        self.toast.writeAssignments(assignments)
    
    def getToastADCSettings(self):
        adc = self.toast.readTLVEntry(Toast.TAG_ADC12_1)
        
        self.toastAdcList = []
        for i in range(0,16,2):
            tmp = (adc[i+1] << 8) + adc[i]
            
            self.toastAdcList.append(tmp)
        return self.toastAdcList

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
        self.toastFrame.disableUI()
        self.adcFrame.disableUI()
        self.graphFrame.sampleSignal(True)

    def stopSampling(self):
        self.sampleThread.stop()
        
        self.baconFrame.enableUI()
        self.toastFrame.enableUI()
        self.adcFrame.enableUI()
        self.graphFrame.sampleSignal(False)


    def readSensor(self, channel, sensorImpedance=10000, warmUpMs = 10, 
      sref = Toast.REFERENCE_VREFplus_AVss, ref2_5v = True, samplePeriod32k = 0):
      
      return self.toast.readSensor(channel, sensorImpedance, warmUpMs, 
      sref, ref2_5v, samplePeriod32k)

    def getReadings(self):
        return self.sampleThread.queue.get(False)

    #
    # database
    #
    def databaseBacon(self):
        bacon = []
        bacon.append(self.baconIdStr)
        bacon.append(time.time())
        bacon.append(self.mfrStr)
        bacon.extend(self.baconAdcList)
        
        self.database.insertBacon(bacon)

    def databaseToast(self):
        toast = []
        toast.append(self.toastIdStr)
        toast.append(time.time())
        toast.extend(self.toastAdcList)
        
        self.database.insertToast(toast)

    def databaseSensors(self):
        sensors = []
        sensors.append(self.toastIdStr)
        sensors.append(self.toastAssignments)
        
        self.database.attachSensors(sensors)

    def databaseRemoveSensors(self):
        self.database.detachSensors(self.toastIdStr)

    def exportCSV(self):
        self.database.exportCSV()
