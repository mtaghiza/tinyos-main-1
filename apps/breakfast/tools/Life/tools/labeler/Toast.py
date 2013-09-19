#!/usr/bin/env python

import time, math

from tools.labeler.Dispatcher import Dispatcher 
from tools.labeler.TOS import TOS
from tools.labeler.BreakfastError import *
from tools.mig import *

class Toast(object):

    # ADC reference voltage
    REFERENCE_AVcc_AVss = 0
    REFERENCE_VREFplus_AVss = 1
    REFERENCE_VeREFplus_AVss = 2
    REFERENCE_AVcc_VREFnegterm = 4
    REFERENCE_VREFplus_VREFnegterm = 5
    REFERENCE_VeREFplus_VREFnegterm = 6

    # ADC calibration fields
    CAL_ADC_25T85 = 7
    CAL_ADC_25T30 = 6
    CAL_ADC_25VREF_FACTOR = 5
    CAL_ADC_15T85 = 4
    CAL_ADC_15T30 = 3
    CAL_ADC_15VREF_FACTOR = 2 
    CAL_ADC_OFFSET = 1
    CAL_ADC_GAIN_FACTOR = 0

    # TLV tags
    TAG_DCO_30  = 0x01              # Toast factory clock calibration, delete
    TAG_VERSION = 0x02              # Required by storage utility
    TAG_DCO_CUSTOM = 0x03           # Toast custom clock calibration, automatically generated on boot
    TAG_GLOBAL_ID = 0x04            # global barcode ID for toast/bacon devices
    TAG_TOAST_ASSIGNMENTS = 0x05    # Toast sensor assignments
    TAG_ADC12_1 = 0x08              # Toast ADC Calibration constants

    busPower = None

    def __init__(self, motestring='serial@/dev/ttyUSB0:115200'):
        self.dispatcher = Dispatcher(motestring)
        
    def stop(self):
        self.dispatcher.stop()
        

    #
    # Toast commands
    #
    def powerOn(self):        
        """ Power on Toast bus.
        """
        if Toast.busPower != 1:
            # power on bus
            msg = SetBusPowerCmdMsg.SetBusPowerCmdMsg()
            msg.set_powerOn(1)
            
            ret = self.dispatcher.send(msg)
            if (ret.get_error() != TOS.SUCCESS) and (ret.get_error() != TOS.EALREADY):
                raise UnexpectedResponseError
            
            Toast.busPower = 1
            
            # give the attached Toast boards time to power up before continuing 
            time.sleep(1)

    def powerOff(self):
        """ Power off Toast bus.
        """
        if Toast.busPower != 0:
            # power off bus
            msg = SetBusPowerCmdMsg.SetBusPowerCmdMsg()
            msg.set_powerOn(0)
            
            ret = self.dispatcher.send(msg)
            if (ret.get_error() != TOS.SUCCESS) and (ret.get_error() != TOS.EALREADY):
                raise UnexpectedResponseError
            
            Toast.busPower = 0

    def discover(self):
        """ Discover attached Toast boards.
        """        
        msg = ScanBusCmdMsg.ScanBusCmdMsg()
        ret = self.dispatcher.send(msg)
        
        if ret.get_numFound() == 0:
            raise NoDeviceError
        elif ret.get_error() != TOS.SUCCESS: 
            raise UnexpectedResponseError

    #
    # Toast   
    #
    def readVersion(self):
        """ Read Toast TLV version number. Autoincroments on each write.
        """
        msg = ReadToastVersionCmdMsg.ReadToastVersionCmdMsg()
        
        ret = self.dispatcher.send(msg)
        if (ret.get_error() == TOS.EINVAL):
            raise TagNotFoundError
        elif ret.get_error() != TOS.SUCCESS:
            raise UnexpectedResponseError
            
        return ret.get_version()

    def writeVersion(self, version):
        """ Write Toast TLV version number. 
        """
        msg = WriteToastVersionCmdMsg.WriteToastVersionCmdMsg()        
        msg.set_version(version)
        
        ret = self.dispatcher.send(msg)
        if ret.get_error() != TOS.SUCCESS:
            raise UnexpectedResponseError

    def readBarcode(self):
        """ Read unique ID from Toast TLV region.
        """
        msg = ReadToastBarcodeIdCmdMsg.ReadToastBarcodeIdCmdMsg()
        
        ret = self.dispatcher.send(msg)
        if (ret.get_error() == TOS.EINVAL):
            raise TagNotFoundError
        elif (ret.get_error() != TOS.SUCCESS):
            raise UnexpectedResponseError
        
        return ret.get_barcodeId()

    def writeBarcode(self, newBarcode):    
        """ Write unique ID to Toast TLV region. Requires input array to have 8 elements.
        """
        msg = WriteToastBarcodeIdCmdMsg.WriteToastBarcodeIdCmdMsg()        

        # consistency check on the given array's length
        if len(newBarcode) != msg.totalSize_barcodeId():
            raise InvalidInputError
        
        msg.set_barcodeId(newBarcode)
        
        ret = self.dispatcher.send(msg)            
        if ret.get_error() != TOS.SUCCESS:
            raise UnexpectedResponseError

    def readAdcConstants(self):
        """ Read ADC constants from Toast TLV region.
        """
        adc = self.readTLVEntry(Toast.TAG_ADC12_1)
        
        return adc[0:16]

    def writeAdcConstants(self, adc):
        """ Write ADC constants to Toast TLV region.
        """
        self.addTLVEntry(Toast.TAG_ADC12_1, adc)


    def readCustomDCO(self):
        """ Read custom DCO constant from Toast TLV region.
        """
        dco = self.readTLVEntry(Toast.TAG_DCO_CUSTOM)
        
        return dco[0:2]

    def writeCustomDCO(self, dco):
        """ Write custom DCO constant to Toast TLV region.
        """
        self.addTLVEntry(Toast.TAG_DCO_CUSTOM, dco)


    #
    # Direct TLV commands
    #
    def initTLV(self, newVersion):
        msg = WriteToastVersionCmdMsg.WriteToastVersionCmdMsg()        
        msg.set_version(newVersion)
        
        ret = self.dispatcher.send(msg)        
        if ret.get_error() != TOS.SUCCESS:
            raise ValueError

    def readTLV(self):
        """ Read entire TLV.
        """
        msg = ReadToastTlvCmdMsg.ReadToastTlvCmdMsg()
        ret = self.dispatcher.send(msg)
        if ret.get_error() != TOS.SUCCESS:
            raise UnexpectedResponseError
        
        return ret.get_tlvs()


    def writeTLV(self, newTLV):
        """ Write entire TLV. Requires input array to have 64 elements.
        """        
        msg = WriteToastTlvCmdMsg.WriteToastTlvCmdMsg()

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
        msg = ReadToastTlvEntryCmdMsg.ReadToastTlvEntryCmdMsg()        
        msg.set_tag(tag)

        ret = self.dispatcher.send(msg)
        if (ret.get_error() == TOS.EINVAL):
            raise TagNotFoundError
        elif (ret.get_error() != TOS.SUCCESS):
            raise UnexpectedResponseError
        
        # the Toast mote uses different reponse types depending on the tag
        if (tag == Toast.TAG_VERSION):
            return ret.get_version()
        elif (tag == Toast.TAG_GLOBAL_ID):
            return ret.get_barcodeId()
        else:
            return ret.get_data()


    def addTLVEntry(self, tag, data):
        """ Add entry to TLV with the specified tag and array. Length is automatically set.
        """
        msg = AddToastTlvEntryCmdMsg.AddToastTlvEntryCmdMsg()
        msg.set_tag(tag)
        msg.set_len(len(data))
        msg.set_data(data)
        
        ret = self.dispatcher.send(msg)
        if ret.get_error() != TOS.SUCCESS:
            raise UnexpectedResponseError
    
    
    def deleteTLVEntry(self, tag):
        """ Delete entry in TLV with the specified tag.
        """
        msg = DeleteToastTlvEntryCmdMsg.DeleteToastTlvEntryCmdMsg()
        msg.set_tag(tag)
        
        ret = self.dispatcher.send(msg)
        if (ret.get_error() == TOS.EINVAL):
            raise TagNotFoundError
        elif ret.get_error() != TOS.SUCCESS:
            raise UnexpectedResponseError


    #
    # Sensor related
    #
    def readAssignments(self):
        """ Read sensor assignments from TLV
        """
        msg = ReadToastAssignmentsCmdMsg.ReadToastAssignmentsCmdMsg()
        msg.set_tag(Toast.TAG_TOAST_ASSIGNMENTS)
        
        ret = self.dispatcher.send(msg)
        if (ret.get_error() == TOS.EINVAL):
            raise TagNotFoundError
        elif ret.get_error() != TOS.SUCCESS:
            raise UnexpectedResponseError
            
        return [ret.get_assignments_sensorId(), ret.get_assignments_sensorType()]

    def writeAssignments(self, assignments):
        """ Write sensor assignments to TLV. Input: ID array, Type array.
        """
        msg = WriteToastAssignmentsCmdMsg.WriteToastAssignmentsCmdMsg()

        [newIds, newTypes] = assignments

        # substitute None with 0 
        for i, n in enumerate(newIds):
            if n is None:
                newIds[i] = 0

        for i, n in enumerate(newTypes):
            if n is None:
                newTypes[i] = 0

        # check size consistency
        if ((len(newIds) != msg.numElements_assignments_sensorId(0)) 
            or (len(newTypes) != msg.numElements_assignments_sensorType(0))):
            raise InvalidInputError
            
        msg.set_assignments_sensorId(newIds)
        msg.set_assignments_sensorType(newTypes)
        msg.set_len(24)

        #print msg
        ret = self.dispatcher.send(msg)
        
        if ret.get_error() == TOS.ESIZE:
            raise OutOfSpaceError # this is a workaround. the bacon should return ENOMEM instead of ESIZE
        elif ret.get_error() != TOS.SUCCESS:
            print ret.get_error()
            raise UnexpectedResponseError


    def readSensor(self, channel, sensorImpedance=10000, warmUpMs = 10, 
      sref = REFERENCE_VREFplus_AVss, ref2_5v = True, samplePeriod32k = 0):
        '''Construct a ReadAnalogSensorCmdMsg based on the sensor
        requirements (computes the various register values required).
        Channels 0-7 are the external sensors. Default impedance and warm-up
        time are chosen fairly conservatively.'''
        
        #list of SAMPLE_HOLD_xx_CYCLES constants. the corresponding enum of
        # the i-th element is i.
        sht_enum_vals = [ 4, 8, 16, 32, 64, 96, 128, 192, 256, 384, 512, 768, 1024]
        
        msg = ReadAnalogSensorCmdMsg.ReadAnalogSensorCmdMsg()
        #direct inputs:
        #input channel
        #voltage range (sref, ref2_5v)
        #warm-up time
        #sample period
        msg.set_inch(channel)
        msg.set_sref(sref)
        msg.set_ref2_5v(ref2_5v)
        msg.set_delayMS(warmUpMs)
        msg.set_samplePeriod(samplePeriod32k)

        #fixed timing values:
        #sampcon_ssel: 1 (ACLK, 32 binary KHz on toast)
        #sampcon_id: 0 (/1)
        #adc12ssel: 3 (SMCLK, 1 binary MHz on toast) 
        #adc12div: 0 (/1)(1 binary uS/tick)
        msg.set_sampcon_ssel(1)
        msg.set_sampcon_id(0)
        msg.set_adc12ssel(3)
        msg.set_adc12div(0)

        #computed values (from sensorImpedance)
        #sht

        #sample time from msp430x2xx user guide, 23.2.4.3. Ci is 40 pF.
        t_sample = (sensorImpedance + 2000)*math.log(2**13)*40e-12 + 800e-9
        #print "t_sample:", t_sample
        #inverse, fyi
        # r = (t_sample - 800e-9)/3.6e-10 - 2000

        #frequency = 1 binary MHz 
        smclkTickLen = 1.0/(2**20.0)
        smclkTicks = t_sample/smclkTickLen
        #print "t_sample (ticks):", smclkTicks
        valid_sht_enums = [i for (i,v) in enumerate(sht_enum_vals) if v > smclkTicks]
        #print "valid enums:", valid_sht_enums
        if valid_sht_enums:
            msg.set_sht(valid_sht_enums[0])
        else:
            raise InvalidInputError("Sensor impedance too high: maximum sample-hold-time is 1 binary ms, roughly 2.8M ohm impedance") 
        
        ret = self.dispatcher.send(msg)
        # Command does not return error_t. Use channel to check for consistency
        if ret.get_sample_inputChannel() != channel:
            raise UnexpectedResponseError
        
        return [ret.get_sample_sampleTime(), ret.get_sample_sample()]
    
if __name__ == '__main__':

    import os
    if os.name == 'nt': 
        toast = Toast('serial@COM26:115200')
    else:
        toast = Toast('serial@/dev/ttyUSB0:115200')
    
    toast.powerOn()
    toast.discover()


    # step 1
    #toast.writeVersion(0)
    
    # step 2 
    # reboot

    #toast.deleteTLVEntry(Toast.TAG_DCO_30)
    
    #adc = toast.readAdcConstants()
    #toast.writeAdcConstants(adc)
    

    tlv = toast.readTLV()
    #tlv[6] = 254
    #tlv[7] = 12
    #tlv[8] = 255
    #tlv[9] = 255
    #tlv[10] = 255
    #tlv[11] = 255
    print tlv
    #toast.writeTLV(tlv)

    
    #print toast.readTLVEntry(Toast.TAG_DCO_CUSTOM)
    #adc = toast.readAdcConstants()
    #toast.writeAdcConstants(adc)

    #dco = toast.readCustomDCO()
    #toast.writeCustomDCO(dco)

    
    #try:
        #print toast.readVersion()
        #print toast.readBarcode()
        #print toast.readTLV()
        #print toast.readTLVEntry(Toast.TAG_VERSION)
        #print toast.readTLVEntry(Toast.TAG_GLOBAL_ID)
        #print toast.readTLVEntry(Toast.TAG_DCO_30)
        #print toast.readTLVEntry(Toast.TAG_DCO_CUSTOM)
        #print toast.readTLVEntry(Toast.TAG_ADC12_1)
    #except:
        #pass
        
    #toast.writeAssignments([[1,2,3,4,5,6,7,8],[1,2,3,4,5,6,7,8]])
    
    #print toast.readAssignments()
    
    #print toast.readSensor(11, 2000, 10)
    #print toast.readSensor(0, 2000, 10)
    #print toast.readSensor(1, 2000, 10)
    #print toast.readSensor(2, 2000, 10)
    #print toast.readSensor(3, 2000, 10)
    #print toast.readSensor(4, 2000, 10)
    #print toast.readSensor(5, 2000, 10)
    #print toast.readSensor(6, 2000, 10)
    #print toast.readSensor(7, 2000, 10)
    #print toast.readSensor(8, 2000, 10)
    
    
    
    toast.powerOff()
    toast.stop()