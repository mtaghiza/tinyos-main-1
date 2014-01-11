#!/usr/bin/env python
import sys

if __name__ == '__main__':
    f = sys.stdin
    if len(sys.argv) > 1:
        f = open(sys.argv[1], 'r')
    ts=None
    for line in f.readlines():
        r = line.strip().split()
        if not ts:
            ts = float(r[1])
            print "Time[s], p0, p1, p2, p3, p4, p5, p6, p7"
            print "%f, 0, 0, 0, 0, 0, 0, 0, 0"%(ts-1)
        else:
            bs = bin(int(r[1], 16))[2:]
            bs = '0'*(8-len(bs))+bs
            bs = bs[::-1]
            print "%f, %s"%((float(r[0])/4000000.0) + ts, ', '.join(c for c in bs))
