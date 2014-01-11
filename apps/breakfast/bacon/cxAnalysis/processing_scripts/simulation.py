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

import pdb
import matplotlib.pyplot as plt
import sys
import networkx as nx
import sqlite3
import random
from math import log, ceil, floor

class Topology(object):
    def __init__(self):
        pass

    def getEdges(self):
        #return edges in [(src,dest, {prr:x, rssi:y})...] form
        pass

class StaticFileTopology(Topology):
    def __init__(self, topoFile):
        super(Topology, self).__init__()
        self.topoFile = topoFile


    def getNodes(self):
        f = open(self.topoFile, 'r')
        nodes = []
        for l in f.readlines():
            if l.startswith('n'):
                r = l.strip().split()[1:4]
                (node, x, y) = (int(r[0]), float(r[1]), float(r[2]))
                nodes.append((node, {'pos':(x,y)}))
        return nodes


    def getEdges(self):
        f = open(self.topoFile, 'r')
        edges = []
        for l in f.readlines():
            if l.startswith('e'):
                r = l.strip().split()[1:5]
                [s, d] = [int(v) for v in r[:2]]
                [prr, rssi] = [float(v) for v in r[-2:]]
                edges.append( (s, d, {'prr':prr, 'rssi':rssi}))
        return edges
        


class TestbedTopology(Topology):
    def __init__(self, dbFile, 
            nsluFile, nodeFile, 
            sr, txp, packetLen, 
            sliceLen):
        super(Topology, self).__init__()
        self.dbFile = dbFile
        self.sr = sr
        self.txp = txp
        self.packetLen = packetLen
        self.sliceLen = sliceLen
        self.nodeFile = nodeFile
        self.nsluFile = nsluFile

    def getNodes(self):
        #read NSLU locations
        f = open(self.nsluFile)
        nslus={}
        for l in f.readlines():
            if not l.startswith("#"):
                [nslu, port, x, y]  = [int(v) for v in l.split()]
                if nslu not in nslus:
                    nslus[nslu] = {}
                nslus[nslu][port] = (x,y)
        
        #read node-nslu mapping and get node locations
        nodes = {}
        f = open(self.nodeFile)
        for l in f.readlines():
            if not l.startswith("#"):
                [nslu, port, nodeId] = [int(v) for v in l.split()]
                if nslu in nslus:
                    nodes[nodeId] = {'pos':nslus[nslu][port], 'nslu':nslu}
                else:
                    #TODO: log missing node error
                    pass
        return [(n, nodes[n]) for n in nodes]
        
    def getEdges(self):
        (start, end) = self.randomTimeSlice()
        return self.getEdgesTimeSlice(start, end)

    def getEdgesTimeSlice(self, startTime, endTime):
        c = sqlite3.connect(self.dbFile)
        c.execute('''DROP TABLE IF EXISTS TXO_TMP''')
        c.execute('''CREATE TEMPORARY TABLE TXO_TMP
                     AS 
                     SELECT * from TXO 
                     WHERE sr=? and txpower=? and len=?
                     AND ts between ? and ?''', 
                     (self.sr, self.txp, 
                       self.packetLen, startTime, endTime))
        links = c.execute('''SELECT txAgg.src, txAgg.dest, 
                      numReceived/numSent as prr,
                      rssi as rssi,
                      lqi as lqi
                      FROM (
                        SELECT src, dest, 
                          1.0*count(*) as numSent
                        FROM TXO_TMP
                        GROUP BY src, dest
                      ) as txAgg
                      JOIN (
                        SELECT src, dest,
                          avg(rssi) as rssi,
                          avg(lqi) as lqi,
                          count(*) as numReceived
                        FROM TXO_TMP
                        WHERE received
                        GROUP BY src, dest
                      ) as rxAgg
                      ON rxAgg.src = txAgg.src 
                        AND rxAgg.dest = txAgg.dest''').fetchall()
        ret = []
        for (src, dest, prr, rssi, lqi) in links:
            ret.append((src, dest, {'prr':prr, 'rssi':rssi}))
        return ret

    def randomTimeSlice(self):
        c = sqlite3.connect(self.dbFile)
        [(start, end)] = c.execute('''SELECT min(ts), max(ts) 
            from txo
            where src = 2 and txpower = ? and sr=? and len=? 
            group by src, txpower, sr, len''', 
          (self.txp, self.sr, self.packetLen)).fetchall()
        end -= self.sliceLen
        startSlice = start + (random.random() * (end - start))
        return (startSlice, startSlice + self.sliceLen)

class SyntheticTopology(TestbedTopology):
    def __init__(self, 
            dbFile, 
            bucketSize,
            density, 
            numNodes,
            aspectRatio,
            cornerRoot,
            nsluFile, nodeFile, 
            sr, txp, packetLen, 
            sliceLen):
        super(SyntheticTopology, self).__init__(dbFile, 
            nsluFile, nodeFile, 
            sr, txp, packetLen, 
            sliceLen)
        self.bucketSize = bucketSize
        self.numNodes = numNodes
        self.density = density
        self.aspectRatio = aspectRatio
        self.cornerRoot = cornerRoot
        self.nodes = []

    def getEdges(self):
        #get the positions of each node from testbed map
        nodes = super(SyntheticTopology, self).getNodes()
        #sample testbed for edges
        edges = super(SyntheticTopology, self).getEdges()
        edgeBuckets = {}
        edgeMap = {}
        #store all the edges which we have data for
        for (s, d, em) in edges:
            edgeMap[(s,d)] = (em['prr'], em['rssi'])
        #put edge data into buckets by inter-node distance, fill in 
        # 0 PRR for pairs of nodes with no link.
        for (s,sm) in nodes:
            for (d, dm) in nodes:
                if d != s:
                    (sx, sy) = sm['pos']
                    (dx, dy) = dm['pos']
                    dist = ((dx-sx)**2 + (dy-sy)**2)**0.5
                    distBucket = floor(dist/self.bucketSize) * self.bucketSize
                    (prr, rssi) = edgeMap.get( (s, d), (0,-100))
                    if distBucket not in edgeBuckets:
                        edgeBuckets[distBucket] = []
                    edgeBuckets[distBucket].append( (prr,rssi))
#         pdb.set_trace()
        #OK, so now we've got our testbed data in buckets. Now we have
        # to iterate over the pairs of nodes in the synthetic topology and
        # create the corresponding edges
        nodes = self.getNodes()
        edges = []
        for (s, sm) in nodes:
            for (d, dm) in nodes:
                if d!=s:
                    (sx, sy) = sm['pos']
                    (dx, dy) = dm['pos']
                    dist = ((dx-sx)**2 + (dy-sy)**2)**0.5
                    distBucket = floor(dist/self.bucketSize) * self.bucketSize
                    if distBucket not in edgeBuckets:
                        edgeBuckets[distBucket] = [(0, -100)]
                    [(prr, rssi)] = random.sample(edgeBuckets[distBucket], 1)
                    if prr != 0:
                        edges.append( (s, d, {'prr':prr, 'rssi':rssi}))
#         pdb.set_trace()
        return edges

    def getNodes(self):
        if not self.nodes:
            self.area = self.numNodes / float(self.density)
            # x*y = A
            # x = ky
            # A = ky**2
            # y = (A/k)**0.5
            # x = A/y
            height = (self.area/self.aspectRatio)**0.5
            width = self.area/height

            if self.cornerRoot:
                self.nodes = [ (0, {'pos':(-1*width/2, -1*height/2)})]
            else:
                self.nodes = [ (0, {'pos':(0, 0)})]

            for n in range(1, self.numNodes):
                x = (random.random()*width) - (width/2)
                y = (random.random()*height) - (height/2)
                self.nodes.append( (n, {'pos':(x, y)}))
        return self.nodes



class Simulation(object):
    def __init__(self, topo):
        '''Create basic data structures and load nodes from topo. '''
        self.G = nx.DiGraph()
        self.topo = topo
        self.G.add_nodes_from(self.topo.getNodes())
    
    def simFloodBatch(self, senders, simRuns):
        '''Run multiple simulation instances with same set of edges'''
        print "loading edges"
        self.loadEdges()
        #reset distance measurements for this batch
        for n in self.G.nodes():
            self.G.node[n]['distances']={}
        print "edges loaded"
        for i in range(simRuns):
            for root in senders:
                self.simFlood(root, i)
            if ((i+1) % 10) == 0:
                print "%d of %d done"%(i+1, simRuns)

    def loadEdges(self):
        '''Use previously-set edge provider to regenerate edges'''
        self.G.remove_edges_from(self.G.edges())
        self.G.add_edges_from(self.topo.getEdges())

    def simFlood(self, root, sn):
        '''Simulate the effect of one flood'''
        self.simInit(root)
        d = 1
        while self.simRound(d):
            d += 1
        for n in self.G.nodes():
            rr = self.G.node[n]['receiveRound']
            if rr != sys.maxint:
                if root not in self.G.node[n]['distances']:
                    self.G.node[n]['distances'][root] = []
                self.G.node[n]['distances'][root].append((sn, rr))

#    def simRound(self):
#        '''Simulate one round of communication events'''

    def simInit(self, root):
        '''Initialize node state for a single data transmission'''
        for n in self.G.nodes():
            self.G.node[n]['receiveRound'] = sys.maxint
        self.G.node[root]['receiveRound'] = 0

    def depthOutput(self, outFile, root=0):
        outFile.write("dest,depth\n")
        for n in self.G.nodes():
            for (sn, rr) in self.G.node[n]['distances'].get(root, []):
                outFile.write('%d,%d\n'%(n, rr))
        outFile.close()

    def textOutput(self, outFile):
        outFile.write("src dest sn depth\n")
        for n in self.G.nodes():
            for src in self.G.node[n]['distances']:
                for (sn, rr) in self.G.node[n]['distances'][src]:
                    outFile.write('%d %d %d %d\n'%(src, n, sn, rr))
        outFile.close()


class NaiveSimulation(Simulation):
    def __init__(self, topo):
        super(NaiveSimulation, self).__init__(topo)

    def simRound(self, d):
        someReceived = False
        for n in self.G.nodes():
            if self.G.node[n]['receiveRound'] == d-1:
                for dest in self.G[n]:
                    if self.G.node[dest]['receiveRound'] == sys.maxint: 
                        if random.random() < self.G[n][dest]['prr']:
                            self.G.node[dest]['receiveRound'] = d
                            someReceived = True
                        else:
                            pass
        return someReceived


class PhySimulation(Simulation):
    def __init__(self, topo, captureThresh, noCaptureLoss,
          noCapMethod, synchLoss):
        super(PhySimulation, self).__init__(topo)
        self.captureThresh = captureThresh
        self.noCaptureLoss = noCaptureLoss
        self.noCapMethod = noCapMethod
        self.synchLoss = synchLoss


    def simRound(self, d):
        receivers = {}
        someReceived = False
        for n in self.G.nodes():
            #accumulate receptions at each node with incoming packets
            if self.G.node[n]['receiveRound'] == d-1:
                for dest in self.G[n]:
                    if self.G.node[dest]['receiveRound'] == sys.maxint:
                        prr = self.G[n][dest]['prr']
                        rssi = self.G[n][dest]['rssi']
                        receivers[dest] = receivers.get(dest, []) + [(prr, rssi)]
        #print receivers
        #pdb.set_trace()
        for n in receivers:
            incoming = receivers[n]
            capturePresent = False
            maxPrr = max(prr for (prr, rssi) in incoming)
            avgPrr = sum(prr for (prr, rssi) in incoming)/float(len(incoming))
            minPrr = sum(prr for (prr, rssi) in incoming)/float(len(incoming))
            if len(incoming) > 1:
                combinedRSSI = self.addRSSIs([rssi for (prr, rssi) in incoming])
                for (prr, rssi) in incoming:
                    if rssi > self.subtractRSSI(combinedRSSI, rssi) + self.captureThresh:
                        capturePresent = True
                        maxPrr = prr
                if capturePresent:
                    shouldReceive = (random.random() < maxPrr)
                else:
                    #this is where we decide how to handle the
                    #  no-capture case.
                    if noCapMethod == 'max':
                        shouldReceive = (random.random() < maxPrr)
                    elif noCapMethod == 'avg':
                        shouldReceive = (random.random() < avgPrr)
                    elif noCapMethod == 'min':
                        shouldReceive = (random.random() < minPrr)
            else:
                capturePresent = True
                shouldReceive = (random.random() < maxPrr)

            if not capturePresent and shouldReceive:
                if len(incoming) == 2:
                    shouldReceive = (random.random() > 2*self.noCaptureLoss)
                else:
                    shouldReceive = (random.random() > self.noCaptureLoss)
                if shouldReceive:
                    shouldReceive = random.random() < (1-self.synchLoss)**(d-1)
            if shouldReceive:
                someReceived = True
                self.G.node[n]['receiveRound'] = d
        return someReceived


    def dbmToWatts(self, x):
        #print "d to w", x
        return 10**((x-30.0)/10)

    def wattsToDbm(self, p):
        #print "w to d",p
        return 10*log(p, 10) + 30

    def addRSSIs(self, rssiVals):
        #print "add", rssiVals
        #TODO: phase interference?
        return self.wattsToDbm(sum([self.dbmToWatts(v) for v in rssiVals]))

    def subtractRSSI(self, minuend, subtrahend):
        #TODO: phase interference?
        return self.wattsToDbm(self.dbmToWatts(minuend) - self.dbmToWatts(subtrahend))

class DistanceMetric(object):
    def __init__(self):
        pass

    def advertiseDistance(self, results):
        return random.sample(results, 1)[0][1]

    def selectDistance(self, results):
        return random.sample(results, 1)[0][1]

class LastDistance(DistanceMetric):
    pass

class AverageDistance(DistanceMetric):
    def selectDistance(self, results):
        distances = [d for (sn, d) in results]
        return round(sum(distances)/float(len(distances)))

    def advertiseDistance(self, results):
        distances = [d for (sn, d) in results]
        return round(sum(distances)/float(len(distances)))

class RoundedAverageDistance(DistanceMetric):
    def selectDistance(self, results):
        distances = [d for (sn, d) in results]
        return floor(sum(distances)/float(len(distances)))

    def advertiseDistance(self, results):
        distances = [d for (sn, d) in results]
        return ceil(sum(distances)/float(len(distances)))


class MaxDistance(DistanceMetric):
    def selectDistance(self, results):
        distances = [d for (sn, d) in results]
        return min(distances)

    def advertiseDistance(self, results):
        distances = [d for (sn, d) in results]
        return max(distances)

def usage():
    print >>sys.stderr, "Usage: python %s [options]"%sys.argv[0]
    print >>sys.stderr, """
  Required options:

    --dbFile <dbFile> : the sqlite db containing connectivity information

  Optional options:

    --nsluFile    : nslu, port, x, y data
    --nodeFile    : nodeID, nslu, port mappings
    --sr          : symbol rate 
    --txp         : transmit power
    --packetLen   : packet length (in payload bytes)
    --sliceLen    : time slice length for segmenting connectivity data
"""

def dn(sim):
    nx.draw_networkx_nodes(sim.G,
      pos=nx.get_node_attributes(sim.G, 'pos'))
    allEdges = sim.G.edges(data=True)
    goodEdges = [ e for e in allEdges if e[-1]['prr'] > 0.9]
    nx.draw_networkx_edges(sim.G,
      pos=nx.get_node_attributes(sim.G, 'pos'),
      edgelist=goodEdges, 
      alpha=0.2, arrows=False)
    nx.draw_networkx_labels(sim.G,
      pos=nx.get_node_attributes(sim.G, 'pos'),
      labels=dict((n,n) for n in sim.G.nodes()))
    plt.show()    

if __name__ == '__main__':
    #default settings
    nodeFile = 'fig_scripts/config/node_map.txt'
    nsluFile = 'fig_scripts/config/nslu_locations.txt'
    sr = 125
    txp = 0x2D
    packetLen = 16
    sliceLen = 10*60
    dbFile = None
    topoFile = None
    dbSyntheticFile = None
    captureThresh = 5
    noCaptureLoss = 0.05
    depthOutFile = None
    textOutFile = None
    noCapMethod = 'min'
    synchLoss = 0
    naive = 0
    numSetups = 5
    testsPerSetup = 30
    dest = 0
    selectionTrials = 20
    bw = 0
    dm = LastDistance()
    slotLen = 40
    diameter = None

    aspectRatio = 1
    #Units are testbed map pixels (lol)
    # 20 px = 50 in
    #       = 127 cm
    # 16 px ~= 1 meter
    bucketSize = 32
    #our testbed spans ~50 x 50 m, and has 66 nodes in it
    # 2500 m2 = 66 nodes
    # 0.0264 nodes / m2
    # a.k.a 38 m2/node
    #densityInv = 38
    densityM2 = 0.0264
    numNodes = 66
    cornerRoot = 1
    randomSeed = None
    fwdRawFile = open('/dev/null', 'w')
    fwdAggFile = open('/dev/null', 'w')
    ipiFile = open('/dev/null', 'w')
    positionOutFile = open('/dev/null', 'w')

    diameterOnly = False

    if len(sys.argv) < 3:
        usage()
        sys.exit(1)
    
    for (opt, val) in zip(sys.argv, sys.argv[1:]):
        if opt == '--dbSynthetic':
            dbSyntheticFile = val        
        if opt == '--fileTopo':
            topoFile = val        
        if opt == '--dbTopo':
            dbFile = val
        if opt == '--nodeFile':
            nodeFile = val
        if opt == '--nsluFile':
            nsluFile = val
        if opt == '--sr':
            sr = int(val)
        if opt == '--txp':
            txp = int(val, 16)
        if opt == '--packetLen':
            packetLen = int(val)
        if opt == '--sliceLen':
            sliceLen = int(val)
        if opt == '--captureThresh':
            captureThresh = float(val)
        if opt == '--noCaptureLoss':
            noCaptureLoss = float(val)
        if opt == '--depthOutFile':
            print "depth output to", val
            depthOutFile = open(val, 'w')
        if opt == '--noCapMethod':
            noCapMethod = val
        if opt == '--synchLoss':
            synchLoss = float(val)
        if opt == '--naive':
            naive = int(val)
        if opt == '--numSetups':
            numSetups = int(val)
        if opt == '--testsPerSetup':
            testsPerSetup = int(val)
        if opt == '--textOutFile':
            print "text output to", val
            textOutFile = open(val, 'w')
        if opt == '--dest':
            dest = int(val)
        if opt == '--selectionTrials':
            selectionTrials = int(val)
        if opt == '--bw':
            bw = int(val)
        if opt == '--distanceMetric':
            if val == 'last':
                dm = LastDistance()
            if val == 'max':
                dm = MaxDistance()
            if val == 'avg':
                dm = AverageDistance()
            if val == 'ravg':
                dm = RoundedAverageDistance()
        if opt == '--slotLen':
            slotLen = int(val)
        if opt == '--fwdRawFile':
            fwdRawFile = open(val, 'w')
        if opt == '--fwdAggFile':
            fwdAggFile = open(val, 'w')
        if opt == '--ipiFile':
            ipiFile = open(val, 'w')
        if opt == '--bucketSize':
            bucketSize = float(val)
        if opt == '--densityM2':
            densityM2 = float(val)
        if opt == '--numNodes':
            numNodes = int(val)
        if opt == '--aspectRatio':
            aspectRatio = float(val)
        if opt == '--cornerRoot':
            cornerRoot = int(val)
        if opt == '--positionOutFile':
            positionOutFile = open(val, 'w')
        if opt == '--seed':
            randomSeed = int(val)
        if opt == '--diameterOnly':
            diameterOnly = int(val)

    if randomSeed:
        random.seed(randomSeed)
        print "Using random seed", randomSeed
    else:
        print >> sys.stderr, "Random seed must be provided"
        sys.exit(1)


    if dbSyntheticFile:
        #roughly 16px to the meter
        density = densityM2 / (16 *16)
        topo = SyntheticTopology(dbSyntheticFile, 
          bucketSize, density, numNodes, aspectRatio, 
          cornerRoot,
          nsluFile, nodeFile, sr, txp,
          packetLen, sliceLen)
    elif dbFile:
        topo = TestbedTopology(dbFile, nsluFile, nodeFile, sr, txp,
          packetLen, sliceLen)
    elif staticTopoFile:
        topo = StaticFileTopology(staticTopoFile)
    else:
        usage()
        sys.exit(1)
        

    if naive:
        sim = NaiveSimulation(topo)
    else:
        sim = PhySimulation(topo, captureThresh, noCaptureLoss,
          noCapMethod, synchLoss)

    print 'root position:', sim.G.node[0]['pos']
    if positionOutFile:
        nodes = topo.getNodes()
        for (n, nm) in nodes:
            positionOutFile.write('%d %0.2f %0.2f\n'%(n, nm['pos'][0], nm['pos'][1]))

    for i in range(numSetups):
        print "Test setup %d of %d"%(i+1, numSetups) 
#         sim.simFloodBatch([0], testsPerSetup) 
        sim.simFloodBatch([n for n in sim.G.nodes()], testsPerSetup) 
    #OK, so now we've got an  n x n x tps matrix of distance
    #  measurements

    if depthOutFile:
        sim.depthOutput(depthOutFile)
    if textOutFile:
        sim.textOutput(textOutFile)

    #TODO: this should be a method of simulation class

    ipi = {}
    for n in sim.G.nodes():
        sim.G.node[n]['forwards'] = []
        ipi[n]=[]
    
    #ignore nodes with no edges, if they appear
    for n in range(selectionTrials):
        for s in sim.G.nodes():
            if s == dest or (dest not in sim.G.node[s]['distances']):
                continue
            #pick d_sd from source measurements
            d_sd = dm.advertiseDistance(sim.G.node[s]['distances'][dest])
            #this indicates the node was unreachable
            if d_sd == sys.maxint:
                continue
            ipi[s].append(d_sd )
            for f in sim.G.nodes():
                #no edges for this node in connectivity graph, ignore it
                if len(sim.G[f]) == 0:
                    continue
                if f == dest or f == s :
                    isForwarder = True
                else:
                    if (s not in sim.G.node[f]['distances'] 
                      or dest not in sim.G.node[f]['distances'] ):
                        isForwarder=False
                    else:
                        d_sf = dm.selectDistance(sim.G.node[f]['distances'][s])
                        d_fd = dm.selectDistance(sim.G.node[f]['distances'][dest])
                        isForwarder = (d_sf + d_fd) <= d_sd + bw
                sim.G.node[f]['forwards'].append((s,  isForwarder))

    diameter = 0
    for n in ipi:
        diameter = max( ipi[n] + [diameter])
    floodDuration = diameter + 1
    
    if diameterOnly:
        print "DIAMETER_INFO", aspectRatio, numNodes, densityM2, cornerRoot, randomSeed, diameter
        sys.exit(0)

    for f in sim.G.nodes():
#        pdb.set_trace()
        if f == dest or len(sim.G[f]) == 0:
            continue
        ipis = ipi[f]
        avgDepth = sum(ipis)/float(len(ipis))
        #number of data packets:
        #  subtract flood duration from slotLen
        dp = [ floor((slotLen - floodDuration)/ d_sd) for d_sd in ipis]
        #burst duration: given by advertised distance + boundary width
        bd = [ d_sd + bw for d_sd in ipis]
        #effective IPI: (setup+ tx)/numData
        eipi = [ (floodDuration + bv*p)/p for (bv,p) in zip(bd, dp)]
        #format: src, distance, effective IPI, flood IPI
        ipiFile.write('%d %0.4f %0.4f %d\n'%( 
          f, 
          avgDepth,
          sum(eipi)/float(len(eipi)),
          floodDuration))

        forwards = sim.G.node[f]['forwards']
        for (src, isForwarder) in forwards:
            #output: src, forwarder, isForwarder
            fwdRawFile.write('%d %d %d\n'%(src, f, isForwarder))
        totalTrials = len(forwards)
        activeTrials = len([ s for (s, isForwarder) in forwards if isForwarder ] )
        #output: src, avgDepth, active, total, fractionActive
        fwdAggFile.write('%d %0.4f %d %d %0.4f\n'%(f, avgDepth, activeTrials, totalTrials,
          float(activeTrials)/totalTrials))
#    pdb.set_trace()

#     #for generating topologies
#     nodes = topo.getNodes()
#     posMap = {}
#     for (n, nm) in nodes:
#         posMap[n] = nm['pos']
# #        print 'p', n, posMap[n][0], posMap[n][1]
# 
#     for i in range(1):
#         edges = topo.getEdges()
#         edgeMap = {}
#         for (s, d, em) in edges:
#             edgeMap[(s,d)] = (em['prr'], em['rssi'])
# #             (sx, sy) = posMap[s]
# #             (dx, dy) = posMap[d]
# #             dist = ((dx-sx)**2 + (dy-sy)**2)**0.5
# #             print s, d, dist, em['prr'], em['rssi']
#         for (s,sm) in nodes:
#             for (d, dm) in nodes:
#                 (sx, sy) = posMap[s]
#                 (dx, dy) = posMap[d]
#                 dist = ((dx-sx)**2 + (dy-sy)**2)**0.5
#                 (prr, rssi) = edgeMap.get( (s,d), (0,-100))
#                 print s, d, dist, prr, rssi
# 
#     sys.exit(0)
