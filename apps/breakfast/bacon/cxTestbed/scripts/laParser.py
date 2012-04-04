#!/usr/bin/env python
import sys

def findEdges(records, column, isRE=1):
    zd = zip(records, records[1:])
    edges = [r 
        for (l,r) in zd 
        if r[1][column] == isRE and l[1][column] != isRE]
    return edges

def parse(f):
    r = [s.strip().split(", ") 
        for s in f.readlines()[1:]]
    records = [(float(rec[0]), map(int, rec[1:]))
        for rec in r]
    return records

