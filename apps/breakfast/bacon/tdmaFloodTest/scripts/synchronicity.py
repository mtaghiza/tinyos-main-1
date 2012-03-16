#!/usr/bin/env python
from laParser import *

if __name__ == '__main__':
    f = open(sys.argv[1], 'r')
    records = parse(f)
    sfd_4 = findEdges(records, 0, 1)
    sfd_5 = findEdges(records, 4, 1)
    #the synchronous sends are done when FS.F indicator is high
    #  (odd-numbered frames)
    sfd_4 = [ r for r in sfd_4 if r[1][2] == 1]
    sfd_5 = [ r for r in sfd_5 if r[1][6] == 1]
    if (len(sfd_4) != len(sfd_5)):
        print "TROUBLE", len(sfd_4), len(sfd_5)
    for (l, r) in zip(sfd_4, sfd_5):
        print l[0], r[0] - l[0]
