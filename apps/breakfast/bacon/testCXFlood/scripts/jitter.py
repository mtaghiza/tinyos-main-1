#!/usr/bin/env python
from laParser import *
import sys

def endPacketOffsets(data):
    f1 = findEdges(data, 6, 1)
    f2 = findEdges(data, 7, 1)
    if (len(f1) != len(f2)):
        print >> sys.stderr, "data length mismatch"
        return 
    else:
        offsets = [(abs(r[0]-l[0]),l,r) for (l,r) in zip(f1,f2)]
        return offsets

def sfdForwardOffsets(data):
    f1 = findEdges(data, 1, 1)
    f2 = findEdges(data, 2, 1)
    #keep only the edges where SFD 0 is low
    f1 = [r for r in f1 if r[1][0] == 0]
    f2 = [r for r in f2 if r[1][0] == 0]
    if (len(f1) != len(f2)):
        print >> sys.stderr, "data length mismatch"
        return 
    else:
        offsets = [(abs(r[0]-l[0]),l,r) for (l,r) in zip(f1,f2)]
        return offsets

def stxForwardOffsets(data):
    f1 = findEdges(data, 4, 1)
    f2 = findEdges(data, 5, 1)
    if (len(f1) != len(f2)):
        print >> sys.stderr, "data length mismatch"
        return 
    else:
        offsets = [(abs(r[0]-l[0]),l,r) for (l,r) in zip(f1,f2)]
        return offsets

   

if __name__=='__main__':
    data = parse(open(sys.argv[1], 'r'))
    if '--sfdForward' in sys.argv:
        results = sfdForwardOffsets(data)
    elif '--endPacketInterrupt' in sys.argv:
        results = endPacketOffsets(data)
    elif '--stxForward' in sys.argv:
        results = stxForwardOffsets(data)

    if '--debug' in sys.argv:
        for o in results:
            print o
    else:
        for o in results:
            print o[0]
