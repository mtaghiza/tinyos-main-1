#!/usr/bin/env python

import sys, time, thread

from tinyos.message import *
from tinyos.message.Message import *
from tinyos.message.SerialPacket import *
from tinyos.packet.Serial import Serial
#import tos
import mig
from mig import *


class PrintfLogger:
    def __init__(self):
        self.buf=''
        pass
    
    def receive(self, src, msg):
        mb = msg.get_buffer()
        if 0 in mb:
            mb = mb[:mb.index(0)]
        sys.stdout.write(''.join(chr(v) for v in mb))

class GenericLogger:
    def __init__(self):
        pass

    def receive(self, src, msg):
        print msg


class Dispatcher:
    def __init__(self, motestring):
        self.sendCount = 0
        self.mif = MoteIF.MoteIF()
        self.tos_source = self.mif.addSource(motestring)
        self.mif.addListener(PrintfLogger(), PrintfMsg.PrintfMsg)
        for messageClass in mig.__all__:
            if 'Response' in messageClass:
                self.mif.addListener(GenericLogger(), 
                  getattr(getattr(mig, messageClass), messageClass))

    def stop(self):
        self.mif.finishAll()

    def send(self, m, dest=0):
        print "Sending",self.sendCount, m
        self.mif.sendMsg(self.tos_source,
            dest,
            m.get_amType(), 0,
            m)
        self.sendCount += 1

REFERENCE_AVcc_AVss = 0
REFERENCE_VREFplus_AVss = 1
REFERENCE_VeREFplus_AVss = 2
REFERENCE_AVcc_VREFnegterm = 4
REFERENCE_VREFplus_VREFnegterm = 5
REFERENCE_VeREFplus_VREFnegterm = 6

#list of SAMPLE_HOLD_xx_CYCLES constants. the corresponding enum of
# the i-th element is i.
sht_enum_vals = [ 4, 8, 16, 32, 64, 96, 128, 192, 256, 384, 512, 768, 1024]


def readAnalog(channel, sensorImpedance, warmUpMs = 0,
  sref = REFERENCE_VREFplus_AVss, ref2_5v = True, samplePeriod32k = 0):
    m = ReadAnalogSensorCmdMsg()
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

    #sample time from msp430x2xx user guide, 23.2.4.3
    t_sample = (sensorImpedance*2000)*3.6e-10 + 800e-9
    #inverse, fyi
    # r = (t_sample - 800e-9)/3.6e-10 - 2000

    #frequency = 1 binary MHz 
    smclkTickLen = 1.0/(2**20.0)
    smclkTicks = t_sample/smclkTickLen
    valid_sht_enums = [i for (i,v) in enumerate(sht_enum_vals) if v > smclkTicks]
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

    d = Dispatcher(packetSource)
    last = None
    time.sleep(1)
    if '--auto' in sys.argv:
        autoType = sys.argv[sys.argv.index('--auto')+1]
        limit = int(sys.argv[sys.argv.index('--auto')+2])
        if autoType == 'ping':
            rm = PingCmdMsg.PingCmdMsg()
        elif autoType == 'readAnalog':
            rm = ReadAnalogSensorCmdMsg()
            rm.set_inch(11)
            
        try:
            #turn on bus
            sbp = SetBusPowerCmdMsg.SetBusPowerCmdMsg()
            sbp.set_powerOn(1)
            d.send(sbp, destination)
            time.sleep(0.25)
            #scan
            sb = ScanBusCmdMsg.ScanBusCmdMsg()
            d.send(sb, destination)
            time.sleep(1)
            while limit != 0:
                d.send(rm, destination)
                time.sleep(0.25)
                limit -= 1
        except KeyboardInterrupt:
            pass
        finally:
            d.stop()
    else:
        try:
            while True:
                time.sleep(0.25)
                mcn = raw_input('''Input message class name (q to quit, blank to resend last). 
  Choices: 
    %s\n?> '''%('\n    '.join(v for v in mig.__all__ if 'Cmd' in v)))
                if not last and not mcn:
                    continue
                if last and not mcn:
                    d.send(last, destination)
                    continue
                if mcn not in mig.__all__:
                    for cn in mig.__all__:
                        if cn.startswith(mcn):
                            mcn = cn
                            break
                if mcn in mig.__all__:           
                    m = getattr(getattr(mig, mcn), mcn)()
                    #ugh, these should be exposed with __set__, __get__ so
                    # that it looks like dictionary access
                    for setter in [s for s in dir(m) if s.startswith('set_')]:
                        if setter == 'set_dummy':
                            v = []
                        elif setter == 'set_tag':
                            continue
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

