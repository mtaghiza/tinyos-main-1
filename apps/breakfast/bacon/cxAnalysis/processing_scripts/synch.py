#!/usr/bin/env python
import sys

def toEdges(records, cols):
    d = [ (r[0], [r[1][c] for c in cols]) for r in records]
    for ((lts, left), (rts, right)) in zip(d, d[1:]):
        diffs = [l^ r for (l,r) in zip(left, right)]
        for (r, d, c) in zip (right, diffs, cols):
            if d:
                print "%.6f, %d, %d"%(rts, c, r)
            

if __name__ == '__main__':
    f = sys.stdin
    if len(sys.argv) > 1:
        f = open(sys.argv[1], 'r')
    records = [(float(r[0]), map(int, r[1:])) 
      for r in [line.strip().split(', ') 
        for line in f.readlines()]]
    e = toEdges(records, [6, 7])
