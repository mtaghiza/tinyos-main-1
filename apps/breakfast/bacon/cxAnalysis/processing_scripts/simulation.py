#!/usr/bin/env python
import sys
import networkx as nx
import sqlite3
import random
from math import log

class Topology(object):
    def __init__(self):
        pass

    def getEdges(self):
        #return edges in [(src,dest, {prr:x, rssi:y})...] form
        pass

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


class Simulation(object):
    def __init__(self, topo):
        '''Create basic data structures and load nodes from topo. '''
        self.G = nx.DiGraph()
        self.topo = topo
        self.maxDepth = 10
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
        for d in range(1, self.maxDepth+1):
            self.simRound(d)
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
        for n in self.G.nodes():
            if self.G.node[n]['receiveRound'] == d-1:
                for dest in self.G[n]:
                    if self.G.node[dest]['receiveRound'] == sys.maxint: 
                        if random.random() < self.G[n][dest]['prr']:
                            self.G.node[dest]['receiveRound'] = d
                        else:
                            pass


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
                shouldReceive = (random.random() > self.noCaptureLoss)
                if shouldReceive:
                    shouldReceive = random.random() < (1-self.synchLoss)**(d-1)
            if shouldReceive:
                self.G.node[n]['receiveRound'] = d


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

if __name__ == '__main__':
    #default settings
    nodeFile = 'fig_scripts/config/node_map.txt'
    nsluFile = 'fig_scripts/config/nslu_locations.txt'
    sr = 125
    txp = 0x8D
    packetLen = 16
    sliceLen = 10*60
    dbFile = None
    captureThresh = 10
    noCaptureLoss = 0.05
    depthOutFile = None
    noCapMethod = 'min'
    synchLoss = 0
    naive = 0
    numSetups = 5


    for (opt, val) in zip(sys.argv, sys.argv[1:]):
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
        if opt == '--dbFile':
            dbFile = val
        if opt == '--captureThresh':
            captureThresh = float(val)
        if opt == '--noCaptureLoss':
            noCaptureLoss = float(val)
        if opt == '--depthOutFile':
            depthOutFile = open(val, 'w')
        if opt == '--noCapMethod':
            noCapMethod = val
        if opt == '--synchLoss':
            synchLoss = float(val)
        if opt == '--naive':
            naive = int(val)
        if opt == '--numSetups':
            numSetups = int(val)

    if not dbFile:
        usage()
        sys.exit(1)
    topo = TestbedTopology(dbFile, nsluFile, nodeFile, sr, txp,
      packetLen, sliceLen)

    if naive:
        sim = NaiveSimulation(topo)
    else:
        sim = PhySimulation(topo, captureThresh, noCaptureLoss,
          noCapMethod, synchLoss)
    for i in range(numSetups):
        print "Test setup %d of %d"%(i+1, numSetups)
        sim.simFloodBatch([0], 30)
    if depthOutFile:
        sim.depthOutput(depthOutFile)
    
