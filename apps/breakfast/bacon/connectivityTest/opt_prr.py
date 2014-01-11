#!/usr/bin/env python

# Copyright (c) 2014 Johns Hopkins University
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# - Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
# - Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the
#   distribution.
# - Neither the name of the copyright holders nor the names of
#   its contributors may be used to endorse or promote products derived
#   from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
# THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.

import sqlite3
import sys

p = {}
d = {}
s = {}
adj = {}

def sp(root):
    d[root] = 0
    cur = root
    u = set([node for node in s])
    while u and d[cur] < sys.maxint:
        u.remove(cur)
        un = u.intersection(set([neighbor for neighbor in adj[cur]]))
        for n in un:
            if d[n] > d[cur] + adj[cur][n]:
                d[n] = d[cur] + adj[cur][n]
                p[n] = cur
        if u:
            cur = sorted([(d[n], n) for n in u])[0][1]
   
def usage():
    print >>sys.stderr, """Usage: python %s <db_file> <txpower> [prr_threshold=0.0]
  Compute the shortest path (using ETX) between node 0 and each leaf
  (and reverse), considering only links with PRR above given threshold.
  Output is 
  
  threshold src dest path_len ETX prr
  
  Where the prr is given by the path length divided by the ETX 
  (e.g. if ETX is 4 and the path length is 2, the end-to-end PRR is 0.5)"""%(sys.argv[0])

if __name__ == '__main__':
    if len(sys.argv) < 3:
        usage()
        sys.exit(1)
    dbName = sys.argv[1]
    txPower = int(sys.argv[2])
    c = sqlite3.connect(dbName)
    threshold = 0.0
    if len(sys.argv) > 2:
        threshold = float(sys.argv[3])
    nodes = [node for (node,) in c.execute('SELECT DISTINCT src FROM TX').fetchall()]
    edges = c.execute('SELECT src, dest, prr from LINK WHERE prr >=?  and txPower == ?',(threshold, txPower)).fetchall()
    adj = dict([(node,{}) for node in nodes])
    for (n0, n1, prr) in edges:
        adj[n0][n1] = prr**-1
    for root in nodes:
        p = dict([(node, None) for node in nodes])
        d = dict([(node, sys.maxint) for node in nodes])
        s = dict([(node, False) for node in nodes])
        sp(root)
        #print d
        #print p
        for leaf in [ node for node in d if node ==0 or root == 0]:
            path = [leaf]
            while p[path[-1]] != None:
                path.append(p[path[-1]])
            path = path[::-1]
            if d[leaf]:
                links = [adj[l][r]**-1 for (l,r) in zip(path, path[1:])]
                print threshold, root, leaf, 
                #print path, links, 
                print len(path)-1, d[leaf], (len(path)-1)/d[leaf]
