#!/usr/bin/env python
from laParser import *
import sys

def framingOffsets(data):
    f1 = findEdges(data, 1, 1) 
    f2 = findEdges(data, 2, 1) 
    #keep only the edges where frameStarted is high
    f1 = [r for r in f1 if r[1][6] == 1]
    f2 = [r for r in f2 if r[1][7] == 1]
    if (len(f1) != len(f2)):
        print >> sys.stderr, "data length mismatch"
        return 
    else:
        offsets = [(abs(r[0]-l[0]),l,r) for (l,r) in zip(f1,f2)]
        return offsets

if __name__=='__main__':
    data = parse(open(sys.argv[1], 'r'))
    results = framingOffsets(data)

    if '--debug' in sys.argv:
        for o in results:
            print o
    else:
        for o in results:
            print o[0]
