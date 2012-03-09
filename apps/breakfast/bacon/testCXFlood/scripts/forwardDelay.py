#!/usr/bin/env python
from laParser import *
import sys
import pdb

def sfdForwardDelays(data, forwarder=1):
    starts = findEdges(data, 0, 1)
    forwards = findEdges(data, forwarder, 1)

    #original transmissions: root-start high, forwarder low
    starts = [r for r in starts if r[1][3] == 1 and r[1][forwarder] == 0 ]
    #forwards: root-start high, root low
    forwards = [r for r in forwards if r[1][3] == 1 and r[1][0] == 0]
    #pdb.set_trace()
    if len(forwards) != len(starts):
        print >> sys.stderr, "data length mismatch"
        return
    else:
        offsets = [(abs(r[0]-l[0]),l,r) for (l,r) in zip(starts,forwards)]
        return offsets
 
if __name__=='__main__':
    data = parse(open(sys.argv[1], 'r'))
    results = sfdForwardDelays(data, 1)
    if '--debug' in sys.argv:
        for o in results:
            print o
    else:
        for o in results:
            print o[0]

