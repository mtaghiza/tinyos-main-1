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

import matplotlib.pyplot as plt
import networkx as nx
import sqlite3
import sys
import random

from TestbedMap import TestbedMap

class PrrClosureMap(TestbedMap):
    def __init__(self, connDbFile, cxDbFile, sr=125, txp=0xC3,
          packetLen=35, **kwargs):
        super(PrrClosureMap, self).__init__(**kwargs)
        self.loadEdges(connDbFile, sr, txp, packetLen)

    def loadEdges(self, dbFile, sr, txp, packetLen):
        c = sqlite3.connect(dbFile)
        links = c.execute('SELECT src, dest, prr FROM link WHERE sr=? AND txPower=? AND len=?', (sr, txp, packetLen)).fetchall()
        for (src, dest, prr) in links:
            self.G.add_edge(src, dest, prr=prr)

    def getP_d(self, node):
        return self.G.node[node]['p_d']

    def setP_d(self, node, depth, val):
        self.getP_d(node)[depth] = val

    #each node has dict attribute p_d: probability of getting packet
    # at a given hop-count
    def closureStart(self, root):
        for n in self.G.nodes():
            nx.set_node_attributes(self.G, 'p_d', {n:{0:0}})
        self.setP_d(root, 0, 1.0)
    
    def closureRoundNode(self, d, n):
        p = []
        e = self.G.in_edges(n, data=True)
        if not e:
            return
        for (src, dest, attrs) in e:
            p_other_last = self.getP_d(src).get(d-1, 0)
            p_rx_this = self.G[src][dest]['prr']
            p.append( (p_other_last, p_rx_this))
#        print "n", n, "d", d, "p", p,
        p_d = self.getP_d(n)
##        print "p_d start", p_d

        #prob that we got it on a previous round
        p_prev = sum([p_d[i] for i in p_d])
        p_prev_inv = 1 - p_prev
#        print "p_prev", p_prev,

        #prob for each link that got it previously to fail
        p_inv = [1-(last*rx) for (last, rx) in p]

        #prob that all such links fail
        p_none = reduce(lambda l,r: l*r, p_inv, 1.0)
        #prob that at least one link succeeds
        p_none_inv = 1 - p_none
#        print "p_some", p_none_inv,

        #prob that we did not get it on previous round AND we did
        # get it this round
        self.setP_d(n, d, p_prev_inv * p_none_inv)
#        print "->", p_d[d]

    def closureRound(self, d):
        for n in self.G.nodes():
            self.closureRoundNode(d, n)

    def computeClosure(self, root=0, maxDepth=10):
        self.closureStart(root)
        for d in range(1, maxDepth+1):
            self.closureRound(d)

    def listDepthProbs(self):
        for n in self.G.nodes():
            p_d = self.getP_d(n)
            probSum = sum(p_d[k] for k in p_d)
            if probSum > 0:
                print n, probSum
                for k in p_d:
                    print "  %d %0.4f"%(k, p_d[k])

    def expectedDepths(self):
        for n in self.G.nodes():
            p_d = self.getP_d(n)
            e_d = sum(p_d[d]*d for d in p_d)
            prr = sum(p_d[d] for d in p_d)
            if prr != 0:
                print n, e_d, prr

class FloodSimMap(TestbedMap):
    def __init__(self, connDbFile, cxDbFile, sr=125, txp=0xC3,
          packetLen=35, **kwargs):
        super(FloodSimMap, self).__init__(**kwargs)
        self.loadEdges(connDbFile, sr, txp, packetLen)

    def loadEdges(self, dbFile, sr, txp, packetLen):
        c = sqlite3.connect(dbFile)
        links = c.execute('SELECT src, dest, prr FROM link WHERE sr=? AND txPower=? AND len=?', (sr, txp, packetLen)).fetchall()
        for (src, dest, prr) in links:
            self.G.add_edge(src, dest, prr=prr)
    
    def simInit(self, root):
        for n in self.G.nodes():
            self.G.node[n]['receiveRound'] = sys.maxint
            if 'simResults' not in self.G.node[n]:
                self.G.node[n]['simResults'] = []
        self.G.node[root]['receiveRound'] = 0

    def simRound(self, d):
#        print "Round", d
        for n in self.G.nodes():
            if self.G.node[n]['receiveRound'] == d-1:
#                print " %d received in %d"%(n, d-1)
                for dest in self.G[n]:
                    if self.G.node[dest]['receiveRound'] == sys.maxint: 
                        if random.random() < self.G[n][dest]['prr']:
#                            print "   sent to %d"%(dest)
                            self.G.node[dest]['receiveRound'] = d
                        else:
                            pass
#                            print "   failed to %d"%(dest)

    def sim(self, root, maxDepth=10):
        self.simInit(root)
        for d in range(1, maxDepth+1):
            self.simRound(d)
        for n in self.G.nodes():
            self.G.node[n]['simResults'].append(self.G.node[n]['receiveRound'])

    def listResults(self):
        for n in self.G.nodes():
            r_all = self.G.node[n]['simResults']
            r_rx  = [v for v in r_all if v != sys.maxint]
            prr = len(r_rx)/float(len(r_all))
            if prr > 0:
                avgDepth = sum(r_rx)/float(len(r_rx))
                print n, avgDepth, prr
            

if __name__ == '__main__':
    cn = sys.argv[1]
#    cxn = sys.argv[2]
    txp=int(sys.argv[2], 16)
    if sys.argv[3] == '-c':
        pcm = PrrClosureMap(cn, 'xxx', scriptDir='fig_scripts',
            txp=txp)
        pcm.computeClosure(0, 4)
        print "=============== COMPUTED ==========="
        pcm.expectedDepths()
    elif sys.argv[3] == '-s':
        print "=============== SIMULATED =========="
        fsm = FloodSimMap(cn, 'xxx', scriptDir='fig_scripts',
            txp=txp)
        for i in range(100):
            fsm.sim(0)
        fsm.listResults()
