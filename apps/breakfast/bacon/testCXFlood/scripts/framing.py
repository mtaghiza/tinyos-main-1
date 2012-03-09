#!/usr/bin/env python
from laParser import *
import sys

def framingOffsets(data, sender=0):
    starts = findEdges(data, 0, 1) 
    f1 = findEdges(data, sender, 1) 
    #keep only the edges where frameStarted is high
    starts = [r for r in starts if r[1][3] == 1]
    f1 = [r for r in f1 if r[1][5+sender] == 1]
    if (len(f1) != len(starts)):
        print >> sys.stderr, "data length mismatch"
        return 
    else:
        offsets = [(abs(r[0]-l[0]),l,r) for (l,r) in zip(starts,f1)]
        return offsets

if __name__=='__main__':
    data = parse(open(sys.argv[1], 'r'))
    results = framingOffsets(data, 2)

    if '--debug' in sys.argv:
        for o in results:
            print o
    else:
        for o in results:
            print o[0]
