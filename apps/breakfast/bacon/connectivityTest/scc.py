#!/usr/bin/env python
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
    txpower = int(sys.argv[2])
    c = sqlite3.connect(dbName)
    nodes = [node for (node,) in c.execute('SELECT DISTINCT src FROM TX').fetchall()]
    for prr in map(float, sys.argv[3:]):
        edges = c.execute(
          'SELECT src, dest from LINK WHERE prr >= ? AND txPower == ?', 
          (prr, txpower)).fetchall()
        adj = createAdj(edges)
        dfs(nodes)
        i_edges = [(n1,n0) for (n0,n1) in edges]
        adj = createAdj(i_edges)
        nodes = [node for (v, node) in sorted([(f[u], u) for u in nodes])[::-1]]
        dfs(nodes)
        print prr, len(trees), trees
