#!/usr/bin/env python

from laParser import *

if __name__ == '__main__':
    #file
    #col0
    #edge0
    #col1
    #edge1
    #filterCol0
    #filterCol0 state
    #filterCol1
    #filterCol1 state
    records = parse(open(sys.argv[1], 'r'))
    col0 = int(sys.argv[2])
    edgeType0 = int(sys.argv[3])
    col1 = int(sys.argv[4])
    edgeType1 = int(sys.argv[5])
    fCol0 = int(sys.argv[6])
    fState0 = int(sys.argv[7])
    fCol1 = int(sys.argv[8])
    fState1 = int(sys.argv[9])

    edge0 = findEdges(records, col0, edgeType0)
    edge0 = [r for r in edge0 
      if r[1][fCol0] == fState0 and r[1][fCol1] == fState1]
    edge1 = findEdges(records, col1, edgeType1)
    edge1 = [r for r in edge1
      if r[1][fCol0] == fState0 and r[1][fCol1] == fState1]

    if (len(edge0) != len(edge1)):
        print "TROUBLE"
        print len(edge0), len(edge1)
        sys.exit(1)
    for ((lt,ld), (rt, rd) ) in zip(edge0, edge1):
        print lt, rt-lt


