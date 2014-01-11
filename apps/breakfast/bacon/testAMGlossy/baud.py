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
