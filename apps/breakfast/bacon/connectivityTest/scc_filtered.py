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

def usage():
    print >>sys.stderr, """Outputs the number and members of the
strongly-connected components in the network, for a given PRR
threshold"""
    print >> sys.stderr, "USAGE: python %s <db_file> <txpower> [threshold...]"%(sys.argv[0])

color = {}
p = {}
f = {}
d = {}
time = 0
adj = {}
trees = []

def dfs(nodes):
    global trees
    global time
    global color
    global p
    trees = []
    color = dict([(node, 'white') for node in nodes])
    p = dict([(node, None) for node in nodes])
    time = 0
    for u in nodes:
        if color[u] == 'white':
            trees.append([])
            dfs_visit(u)

def dfs_visit(u):
    global trees
    global time
    global color
    global p
    global d
    global f
    trees[-1].append(u)
    color[u] = 'gray'
    time = time + 1
    d[u] = time
    for v in adj[u]:
        if color[v] == 'white':
            p[v] = u
            dfs_visit(v)
    color[u] = 'black' 
    time = time + 1
    f[u] = time

def createAdj(edges):
    adj = dict([(node,[]) for node in nodes])
    for (n0, n1) in edges:
        adj[n0].append(n1)
    return adj


if __name__ == '__main__':
    if len(sys.argv) < 3:
        usage()
        sys.exit(1)
    dbName = sys.argv[1]
    nodeFile = open(sys.argv[2], 'r')
    c = sqlite3.connect(dbName)
    nodes = []
    for line in nodeFile:
        if not line.startswith('#'):
            nodes.append(int(line.split()[-2]))
#     nodes = [node for (node,) in c.execute('SELECT DISTINCT src FROM TX').fetchall()]
    print "using nodes", nodes
    nodeStr = '('+','.join(str(node) for node in nodes) + ')'
    for prr in map(float, sys.argv[3:]):
        edges = c.execute(
          'SELECT src, dest from AGG WHERE prr >= ? AND src in '+nodeStr+' and dest in '+nodeStr, 
          (prr,)).fetchall()
        adj = createAdj(edges)
        dfs(nodes)
        i_edges = [(n1,n0) for (n0,n1) in edges]
        adj = createAdj(i_edges)
        nodes = [node for (v, node) in sorted([(f[u], u) for u in nodes])[::-1]]
        dfs(nodes)
        print prr, len(trees), trees
