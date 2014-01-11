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


def bfs(adj, root, d):
    pass

def createAdj(edges):
    adj = dict([(node,[]) for node in nodes])
    for (n0, n1) in edges:
        adj[n0].append(n1)
    return adj

def distanceMatrix(nodes, edges):
    m = {}
    #initialize matrix: distance = inf. for all pairs, 0 for self
    for n in nodes:
        m[n] = dict([(node, sys.maxint) for node in nodes])
        m[n][n] = 0
    #add in the edges
    for (n0, n1) in edges:
        m[n0][n1] = 1
    return m

def computeDepths(m):
    #for each intermediate node
    for k in m:
        #for each source
        for i in m:
            #for each destination
            for j in m:
                #set distance from source to destination to min of 
                # existing path or path through intermediate node
                m[i][j] = min(m[i][j], m[i][k] + m[k][j])
    return m

def usage():
    print >> sys.stderr, """Usage: %s <dbName> <txPower> [threshold...]

  Fills in the DEPTH table of specified DB using the point-to-point
  distances for all pairs of nodes, considering edges with PRR >
  specified thresholds.
"""%sys.argv[0]


if __name__ == '__main__':
    if len(sys.argv) < 3:
        usage()
        sys.exit(1)
    dbName = sys.argv[1]
    txpower = int(sys.argv[2])
    c = sqlite3.connect(dbName)
    nodes = [node for (node,) in c.execute('SELECT DISTINCT src FROM TX').fetchall()]
    for prr in map(float, sys.argv[3:]):
        edges = c.execute(
          'SELECT src, dest from LINK WHERE prr >= ? AND txPower == ?', 
          (prr, txpower)).fetchall()
        m = distanceMatrix(nodes, edges)
        d = computeDepths(m)
        c.execute('DELETE FROM depth WHERE prrThreshold = ? AND txPower =?', (prr, txpower))
        for src in d:
            for dest in d[src]:
#                print "inserting",src,dest,d[src][dest]
                c.execute('''INSERT INTO depth (src, 
                  dest, 
                  avgDepth,
                  prrThreshold, 
                  txPower ) VALUES (?, ?, ?, ?, ?)''', 
                  (src, dest, d[src][dest], prr, txpower))
        c.commit()
        c.close()
