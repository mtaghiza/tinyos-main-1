#!/usr/bin/env python
import sys
import pdb

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
#24: TTL

#---- am header
#25: nalp: 0x3f
#26: am type: 0xe0=leaf schedule

#---- body of schedule announcement
#27: scheduleNum: 1
#28: symbol rate: 0x7d=125
#29: channel 0
#30-31: num slots (2)
#32-33: frames per slot (5)
#34: max retransmit: 1
#35-36: firstIdle: 1
#37-38: lastIdle: 1
#39-58: availableSlots (all 0xffff)

#----- end o' the packet
#? 59-63: this is an artifact of the sniffing process (reading past
#         end of packet, dummy)

#802.15.4 header -> end of availableSlots(skipping count field)
ref_indices = range(57)
dec_indices = [24]
inc_indices = [13]

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
    
    printLocations = 1
    countOfInterest = 2
    printRaw=0
    if len(sys.argv) > 1:
        for (o,v) in zip(sys.argv, sys.argv[1:]):
            if o == '-f':
                f = open(v, 'r')
            if o == '-l':
                printLocations = int(v)
            if o == '-r':
                printRaw = int(v)
    b = []
    lastB = []
    refBytes = []
    refSN = -1
    for line in f:
        l = line.strip()
        s = l.split()[3]
        ts = float(l.split()[0])
        lastB = b
        b = toBytes(s)
        if len(b) < 14:
            continue
        sn = (b[11] << 8) + b[12]
        count = b[13]
        crcPassed = 1 if int(l.split()[-1]) != 0 else 0
        if crcPassed and count==1:
            for i in dec_indices:
                b[i] -= (countOfInterest -1)
            for i in inc_indices:
                b[i] += (countOfInterest -1)
            refBytes = [b[i] for i in ref_indices]
            refSN = sn
            errorTotal = 0
            print "ORIG",ts, sn
            if printRaw:
                print "RAW", ts, sn, count, ''.join('%02X'%v for v in b)
        else:
            rb = refBytes
            if len(b) <= max(ref_indices):
                continue
            if sn == refSN and refBytes:
              tb = [b[i] for i in ref_indices]
              errors = [ (v ^ refV) for (v, refV) in zip(tb, rb)]
              errorLocs = [findErrors(v) for v in errors]
              errorLocs = [ [i*8+v for v in l] for (i, l) in enumerate(errorLocs)]
              errorLocs = reduce(lambda x,y: x+y, errorLocs, [])
              errorTotal = len(errorLocs)
              if count == countOfInterest:
                  if printLocations: 
                      for l in errorLocs:
                          print "LOC",ts,l
                  print "BER", ts, sn, crcPassed, count, errorTotal, len(refBytes)*8
                  if printRaw:
                      print "RAW", ts, sn, count, ''.join('%02X'%v for v in b)
