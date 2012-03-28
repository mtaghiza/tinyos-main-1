#!/usr/bin/env python

from laParser import *

if __name__ == '__main__':
    #file
    #col0
    #col1
    #edge type
    records = parse(open(sys.argv[1], 'r'))
    col0 = int(sys.argv[2])
    edgeType = int(sys.argv[3])
    if(edgeType == 0):
        opposite = 1
    else:
        opposite = 0
    edge0 = findEdges(records, col0, edgeType)
    edge1 = findEdges(records, col0, opposite)
    if (len(edge0) != len(edge1)):
        print "TROUBLE"
        print len(edge0), len(edge1)
        sys.exit(1)
    for ((lt,ld), (rt, rd) ) in zip(edge0, edge1):
        print lt, rt-lt


