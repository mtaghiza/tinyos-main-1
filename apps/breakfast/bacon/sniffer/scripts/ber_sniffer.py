#!/usr/bin/env python
import sys
import re
import pdb

COUNT_INDEX = 17

def toInt(x):
    return reduce(lambda l,r: (l<<8) + r, x)

def findErrors(b):
    errors = []
    p = 7
    while b:
        if (b & 0x01):
            errors.append(p)
        b = (b >> 1)
        p -= 1
    return errors

def countErrors(b):
    acc = 0
    while b:
        acc += (b & 0x01)
        b = (b >> 1)
    return acc

def computeStats(fn):
    lp = re.compile("""^[0-9]*.[0-9]* [0-9]*( [0-9A-F]{2})* -[0-9]*""")
    f = open(fn, 'r')
    prev = None
    sns = []
    failures = []
    rxCount = 0
    for line in f:
        
        if not lp.match(line):
            pass
#            print "No match:", line
        else:
#            print "match:", line
            r = [int(v, 16) for v in line.strip().split()[2:]]
            if len(r) <= 18:
                continue
            pkt = r[0:-3]
            crcPassed = r[-3] == 0x80
            lqi = r[-2]
            rssi = r[-1]
            src = toInt(pkt[8:10])
            count = toInt(pkt[17:18])
            sn = toInt(pkt[12:16])
#            pdb.set_trace()
#            print crcPassed, sn, count, src, pkt
            if count == 1 and src == 0:
                prev = (sn, pkt)
                sns.append(sn)
            if count == 2 and src == 0 and sn == prev[0]:
                rxCount += 1
            if not crcPassed and sn == prev[0] and src == 0 and count==2:
#                errorCounts = [countErrors(lv ^ rv) for (lv, rv) in zip(prev[1], pkt)] 
                errorOffsets = [findErrors(lv ^ rv) for (lv, rv) in zip(prev[1], pkt)] 
                bitErrors = []
                for (i, eo) in enumerate(errorOffsets):
                    if i != COUNT_INDEX:
                        for b in eo:
                            bitErrors.append(i*8+b)

#                errorLocs = [  for (i, eo) in enumerate(errorOffsets)] 
#                locs = [(i, c) for (i, c) in enumerate(errors) if c > 0 and i != COUNT_INDEX]
                failures.append( (count, bitErrors))
                if bitErrors and '-v' in sys.argv:
                    print bitErrors, zip(range(len(pkt)), prev[1], pkt)
                if '--all' in sys.argv:
                    print failures[-1]
    if '--pos' in sys.argv:
        p = {}
        for f in failures:
            for l in f[1]:
                p[l] = p.get(l,0) + 1
        for l in p:
            print l, p[l]
    #PRR, including failed CRCs
    prrAll = float(rxCount)/len(sns)
    #PRR, only passed
    prrPassed = (float(rxCount)-len(failures))/len(sns)
    #CRC failure rate
    crcFailureRate = float(len(failures))/rxCount
    #BER computation
    errorCount = 0
    for f in failures:
        errorCount += len(f[-1])
    ber = float(errorCount)/(8*len(sns) * len(prev[-1]))
    sr = int(fn.split('_')[-1])*1000
    return (sr, ber, crcFailureRate, prrAll, prrPassed)
    

if __name__ == '__main__':
    print "SR BER CRC_ERR PRR_ALL PRR_PASSED"
    for fn in sys.argv[1:]:
        result = computeStats(fn)
        print "%i %.6f %.4f %.4f %.4f"%result
