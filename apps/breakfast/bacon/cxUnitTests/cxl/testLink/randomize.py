#!/usr/bin/env python
import sys
import sqlite3
import random

if __name__ == '__main__':
    if len(sys.argv) < 6:
        print >> sys.stderr, "Usage: python %s db (cx|sp) src dest failRate"%(sys.argv[0],)
        sys.exit(1)
    db = sys.argv[1]
    setup = sys.argv[2]
    src=int(sys.argv[3])
    dest=int(sys.argv[4])
    fr=float(sys.argv[5])
    c = sqlite3.connect(db)
    q=''
    if setup == 'cx':
        q = 'SELECT f FROM CXFS where src=? and dest=? and bw=2'
    elif setup=='sp':
        q = 'SELECT f FROM sp_thresh_entry where src=? and dest=? and prr=0.99'
    elif setup=='spe':
        q = 'SELECT f FROM sp_etx_entry where src=? and dest=?'
        

    for (f,) in c.execute(q, (src, dest)).fetchall():
        if f == src or f==dest or random.random() > fr:
            print "%d r"%(f,)
        else:
            print "%d q"%(f,)
