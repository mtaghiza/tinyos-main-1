#!/usr/bin/env python
from math import log
import sys

def br(drate_e, drate_m, f_osc=26000000):
    return (((256+drate_m)*(2.0**drate_e))/(2.0**28))*f_osc

def listRanges():
    for drate_e in range(0x10):
        print "DRATE_E: %x\tmin: %d\tmax: %d"%(drate_e, br(drate_e, 0),
          br(drate_e, 0xff))

def listSettings(drate_e):
    for drate_m in range(0x100):
        print "DRATE_E: %x\tDRATE_M: %x\tmin: %d\tmax: %d"%(drate_e, 
          drate_m, 
          br(drate_e, drate_m),
          br(drate_e, drate_m))

def computeSettings(baud):
    #meh, just brute force it
    for drate_e in range(0x10):
        if baud >= br(drate_e, 0) and baud <= br(drate_e, 0xff):
            error = sys.maxint
            mantissa = 0
            for drate_m in range(0x100):
                b = br(drate_e, drate_m)
                if abs(baud-b) < error:
                    error = abs(baud-b)
                    mantissa = drate_m
            return (drate_e, mantissa, error)
    return None

if __name__ == '__main__':
    if len(sys.argv) > 1:
        target = float(sys.argv[1])
        result = computeSettings(target)
        if result:
            (drate_e, drate_m, err) = result
            print "MDMCFG4.DRATE_E: %x"%drate_e
            print "MDMCFG3.DRATE_M: %x"%drate_m
            print "Actual baud: %f (%f from target %f)"%(br(drate_e,
                drate_m), err, target)
        else:
            print "Out of range!"
