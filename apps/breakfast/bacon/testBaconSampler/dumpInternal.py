#!/usr/bin/env python
from dump import *

class BaconSampleLogger(object):
    def __init__(self):
        pass
    
    def receive(self, record):
        (cookieVal, lenVal, recordType, recordData) = record
        rc = toUnsigned(recordData[0:2])
        bt = toUnsigned(recordData[2:6])
        battery = toUnsigned(recordData[6:8])
        light = toUnsigned(recordData[8:10])
        thermistor = toUnsigned(recordData[10:12])
        print "# BACONSAMPLE", rc, bt, bt/1024.0, battery, light, thermistor

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
    d.rl.addListener(0x14, BaconSampleLogger())

    try:
        while True:
            pass
    #these two exceptions should just make us clean up/quit
    except KeyboardInterrupt:
        pass
    except EOFError:
        pass
    finally:
        print "Cleaning up"
        d.stop()


