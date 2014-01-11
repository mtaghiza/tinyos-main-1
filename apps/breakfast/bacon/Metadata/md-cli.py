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


import sys, time, thread
from threading import Lock, Condition

from tinyos.message import *
from tinyos.message.Message import *
from tinyos.message.SerialPacket import *
from tinyos.packet.Serial import Serial
#import tos
import tools.mig
from tools.mig import *

import math

import Queue


class PrintfLogger(object):
    def __init__(self):
        self.buf=''
        pass
    
    def receive(self, src, msg):
        mb = msg.get_buffer()
        if 0 in mb:
            mb = mb[:mb.index(0)]
        sys.stdout.write(''.join(chr(v) for v in mb))

class GenericLogger(object):
    
    def __init__(self, quiet):
        self.quiet = quiet
        pass

    def receive(self, src, msg):
        if not self.quiet:
            print msg

class ADCLogger(object):
    """Prettier ADC sampling output. Notify listeners on response
    condition variable when response received."""

    def __init__(self, responseCV):
        self.responseCV = responseCV
        pass

    def receive(self, src, msg):
        with self.responseCV:
            print "%0.2f %u %0.4f"%(time.time(), 
              msg.get_sample_inputChannel(),
              ((msg.get_sample_sample() * 2.5)/4096.0))
            self.responseCV.notify()

class ScanListener(object):
    def __init__(self, responseQueue):
        self.responseQueue = responseQueue

    def receive(self, src, msg):
        self.responseQueue.put(msg.get_numFound())

class TLVParser(object):
    def __init__(self):
        pass

    def receive(self, src, msg):
        tlv = msg.get_tlvs()
        crc = tlv[0:2]
        tlvi = 0
        tlv = tlv[2:]
        print "TLV",tlv
        print "CRC", crc
        while tlv:
            k = tlv[0]
            l = tlv[1]
            d = tlv[2:2+l]
            print "(%s, %s, [%s])"%(hex(k), hex(l), ', '.join([hex(v) for v in d]))
            tlv = tlv[2+l:]
        


class Dispatcher:
    def __init__(self, motestring, quiet=False):
        self.quiet = quiet
        self.sendCount = 0
        #hook up to mote
        self.mif = MoteIF.MoteIF()
        self.tos_source = self.mif.addSource(motestring)
        #format printf's correctly
        self.mif.addListener(PrintfLogger(), PrintfMsg.PrintfMsg)
        #ADC responses: permit blocking behavior
        self.responseLock = Lock()
        self.responseCV = Condition(self.responseLock)
        self.mif.addListener(ADCLogger(self.responseCV), ReadAnalogSensorResponseMsg.ReadAnalogSensorResponseMsg)
        self.mif.addListener(TLVParser(),
          tools.mig.ReadBaconTlvResponseMsg.ReadBaconTlvResponseMsg)
        self.mif.addListener(TLVParser(),
          tools.mig.ReadToastTlvResponseMsg.ReadToastTlvResponseMsg)
        for messageClass in tools.mig.__all__:
            if 'Response' in messageClass:
                self.mif.addListener(GenericLogger(self.quiet), 
                  getattr(getattr(tools.mig, messageClass), messageClass))

    def stop(self):
        self.mif.finishAll()

    def send(self, m, dest=0):
        if not self.quiet:
            print "Sending",self.sendCount, m
        self.mif.sendMsg(self.tos_source,
            dest,
            m.get_amType(), 0,
            m)
        self.sendCount += 1

    def initialize(self, destination):
        #ugh: not guaranteed that the serial connection is fully
        # opened by the time that you get done with the constructor...
        time.sleep(1)
        #turn on bus
        sbp = SetBusPowerCmdMsg.SetBusPowerCmdMsg()
        sbp.set_powerOn(1)
        self.send(sbp, destination)
        time.sleep(0.25)
        #scan
        sb = ScanBusCmdMsg.ScanBusCmdMsg()
        self.send(sb, destination)
        time.sleep(2)

REFERENCE_AVcc_AVss = 0
REFERENCE_VREFplus_AVss = 1
REFERENCE_VeREFplus_AVss = 2
REFERENCE_AVcc_VREFnegterm = 4
REFERENCE_VREFplus_VREFnegterm = 5
REFERENCE_VeREFplus_VREFnegterm = 6

#list of SAMPLE_HOLD_xx_CYCLES constants. the corresponding enum of
# the i-th element is i.
sht_enum_vals = [ 4, 8, 16, 32, 64, 96, 128, 192, 256, 384, 512, 768, 1024]



def readAnalog(channel, sensorImpedance=10000, warmUpMs = 10, 
  sref = REFERENCE_VREFplus_AVss, ref2_5v = True, samplePeriod32k = 0):
    '''Construct a ReadAnalogSensorCmdMsg based on the sensor
    requirements (computes the various register values required).
    Channels 0-7 are the external sensors. Default impedance and warm-up
    time are chosen fairly conservatively.'''

    m = ReadAnalogSensorCmdMsg.ReadAnalogSensorCmdMsg()
    #direct inputs:
    #input channel
    #voltage range (sref, ref2_5v)
    #warm-up time
    #sample period
    m.set_inch(channel)
    m.set_sref(sref)
    m.set_ref2_5v(ref2_5v)
    m.set_delayMS(warmUpMs)
    m.set_samplePeriod(samplePeriod32k)

    #fixed timing values:
    #sampcon_ssel: 1 (ACLK, 32 binary KHz on toast)
    #sampcon_id: 0 (/1)
    #adc12ssel: 3 (SMCLK, 1 binary MHz on toast) 
    #adc12div: 0 (/1)(1 binary uS/tick)
    m.set_sampcon_ssel(1)
    m.set_sampcon_id(0)
    m.set_adc12ssel(3)
    m.set_adc12div(0)

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
        m.set_sht(valid_sht_enums[0])
    else:
        raise Exception("Sensor impedance too high: maximum sample-hold-time is 1 binary ms, roughly 2.8M ohm impedance") 

    return m
    

if __name__ == '__main__':
    packetSource = 'serial@/dev/ttyUSB0:115200'
    destination = 1

    if len(sys.argv) < 1:
        print "Usage:", sys.argv[0], "[packetSource=serial@/dev/ttyUSB0:115200] [destination=0x01]" 
        sys.exit()

    if len(sys.argv) > 1:
        packetSource = sys.argv[1]
    if len(sys.argv) > 2:
        destination = int(sys.argv[2], 16)
    
    print packetSource

    last = None
    if '--auto' in sys.argv:
        autoType = sys.argv[sys.argv.index('--auto')+1]
        limit = int(sys.argv[sys.argv.index('--auto')+2])
        waitForResponse = True
        quiet = True
        if autoType == 'readAnalog':
            inch = 0
        if autoType == 'ping':
            waitForResponse = False
            quiet = False
        d = Dispatcher(packetSource, quiet)
            
        try:
            if autoType == 'scan':
                responseQueue = Queue.Queue()
                d.mif.addListener(ScanListener(responseQueue),
                  tools.mig.ScanBusResponseMsg.ScanBusResponseMsg)
                d.initialize(destination)
                try:
                    numFound = responseQueue.get(True, 0.5)
                    if numFound:
                        print "PASS: %u TOAST BOARDS FOUND"%numFound
                    else:
                        print "FAIL: TOAST BOARD NOT DETECTED"
                except Queue.Empty:
                    print "RETRY: BACON COMMUNICATION FAILED"
            else:
                d.initialize(destination)
                while limit != 0:
                    if autoType == 'ping':
                        rm = PingCmdMsg.PingCmdMsg()
                    elif autoType == 'readInternal':
                        rm = readAnalog(11, 2000, 10)
                    elif autoType == 'readAnalog':
                        rm = readAnalog(inch, 2000, 10)
                    
                    #acquire response lock, send the request, and then
                    # block until response or timeout 
                    if waitForResponse:
                        with d.responseCV:
                            d.send(rm, destination)
                            d.responseCV.wait(0.25)
                    else:
                        d.send(rm, destination)
                        time.sleep(0.25)
    
                    limit -= 1
                    if autoType == 'readAnalog':
                        inch = (inch + 1)%8
                        #sleep 
                        if inch == 0:
                            time.sleep(1.0)
        except KeyboardInterrupt:
            pass
        finally:
            d.stop()
    else:
        d = Dispatcher(packetSource, quiet=False)
        try:
            d.initialize(destination)
            while True:
                time.sleep(0.25)
                mcn = raw_input('''Input message class name (q to quit, blank to resend last). 
  Choices: 
    %s\n?> '''%('\n    '.join(v for v in tools.mig.__all__ if 'Cmd' in v)))
                if not last and not mcn:
                    continue
                if last and not mcn:
                    d.send(last, destination)
                    continue
                if mcn not in tools.mig.__all__:
                    for cn in tools.mig.__all__:
                        if cn.startswith(mcn):
                            mcn = cn
                            break
                if mcn in tools.mig.__all__:           
                    m = getattr(getattr(tools.mig, mcn), mcn)()
                    #ugh, these should be exposed with __set__, __get__ so
                    # that it looks like dictionary access
                    for setter in [s for s in dir(m) if s.startswith('set_')]:
                        if setter == 'set_dummy':
                            v = []
#                         elif setter == 'set_tag':
#                             continue
                        else:
                            v = eval(raw_input('%s:'%setter),
                              {"__builtins__":None}, {})
                            print v
                        getattr(m, setter)(v)
                    d.send(m, destination)
                    last = m
                if mcn == 'q':
                    break
    
        #these two exceptions should just make us clean up/quit
        except KeyboardInterrupt:
            pass
        except EOFError:
            pass
        finally:
            print "Cleaning up"
            d.stop()

