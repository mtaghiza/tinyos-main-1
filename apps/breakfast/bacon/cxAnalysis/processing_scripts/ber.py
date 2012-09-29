#!/usr/bin/env python
import sys

##OK, here's what's in the packet.
#0-1: 15.4 header 
fixed_0 = [ 0x41, 0x88 ]
#! 2 802.15.4 sn: one byte
#3-6: 15.4 header 
fixed_1 = [0x16, 0x00, 0xff, 0xff]
#7-8: am_addr(LSB first)

#-----start of cx header
#9-10: CX dest (0xffff = broadcast)
fixed_2 = [0xff, 0xff]
#! 11-12: CX SN: 2 bytes
#! 13: count
#14: scheduleNum: 1
#15-16: originalFrameNum: 0 
#17-20: timestamp: 0
#21: nProto: 1= flood
#22: tProto: 1= flood
#23: type: nType = 1, tType =1

#---- am header
#24: nalp: 0x3f
#25: am type: 0xe0=leaf schedule

#---- body of schedule announcement
#26: scheduleNum: 1
#27: symbol rate: 0x7d=125
#28: channel 0
#29-30: num slots (2)
#31-32: frames per slot (5)
#33: max retransmit: 1
#34-35: firstIdle: 1
#36-37: lastIdle: 1
#38-57: availableSlots (all 0xffff)

#----- end o' the packet
#? 58-63: this is an artifact of the sniffing process (reading past
#         end of packet, dummy)

#802.15.4 header -> end of availableSlots(skipping count field)
ref_indices = range(13) + range(14, 58)

def toBytes(s):
    return [int(l+r, 16) for (l,r) in zip(s[::2], s[1::2])]

def findErrors(b):
    errors = []
    p = 7
    while b:
        if (b & 0x01):
            errors.append(p)
        b = (b >> 1)
        p -= 1
    return reversed(errors)

if __name__ == '__main__':
    f = sys.stdin

    printLocations = False
    countOfInterest = 3
    if len(sys.argv) > 1:
        for (o,v) in zip(sys.argv, sys.argv[1:]):
            if o == '-f':
                f = open(sys.argv[1], 'r')
            if o == '-l':
                printLocations = int(v)
            if o == '-c':
                countOfInterest=int(v)

    b = []
    lastB = []
    refBytes = []
    refSN = -1
    for line in f:
        l = line.strip()
        s = l.split()[3]
        lastB = b
        b = toBytes(s)
        if len(b) < 14:
            continue
        sn = (b[11] << 8) + b[12]
        count = b[13]
        crcPassed = 1 if int(l.split()[-2]) != 0 else 0
        cycle = int(l.split()[-1])
        if crcPassed and count==1:
            refBytes = [b[i] for i in ref_indices]
            refSN = sn
            errorTotal = 0
        else:
            rb = refBytes
            if len(b) <= max(ref_indices):
                continue
            tb = [b[i] for i in ref_indices]
            if sn == refSN and refBytes:
              errors = [ (v ^ refV) for (v, refV) in zip(tb, rb)]
              errorLocs = [findErrors(v) for v in errors]
              errorLocs = [ [i*8+v for v in l] for (i, l) in enumerate(errorLocs)]
              errorLocs = reduce(lambda x,y: x+y, errorLocs, [])
              errorTotal = len(errorLocs)
              if count == countOfInterest:
                if printLocations: 
                    for l in errorLocs:
                        print l
                else:
                    print cycle, sn, crcPassed, count, errorTotal, len(refBytes)*8
                    continue
