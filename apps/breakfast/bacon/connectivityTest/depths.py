#!/usr/bin/env python
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
