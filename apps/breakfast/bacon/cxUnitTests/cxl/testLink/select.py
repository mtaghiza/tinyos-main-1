#!/usr/bin/env python
import sys
import sqlite3
import random

if __name__ == '__main__':
    db = sys.argv[1]
    hcl = float(sys.argv[2])
    hch = float(sys.argv[3])
    numPairs = int(sys.argv[4])
    q = '''SELECT src, dest, hc, prr FROM mtl WHERE hc >= ? and hc <= ?'''
    c = sqlite3.connect(db)
    pairsInRange = c.execute(q, (hcl, hch)).fetchall()
    pairsSelected = random.sample(pairsInRange, min(numPairs,
      len(pairsInRange)))
    for (s, d, hc, prr) in pairsSelected:
        print "%d %d %0.4f %0.4f"%(s, d, hc, prr)
