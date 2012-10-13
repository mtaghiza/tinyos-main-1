#!/usr/bin/env python
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

class FileTopology(Topology):
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
        return min(distances)

    def advertiseDistance(self, results):
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

if __name__ == '__main__':
    #default settings
    nodeFile = 'fig_scripts/config/node_map.txt'
    nsluFile = 'fig_scripts/config/nslu_locations.txt'
    sr = 125
    txp = 0x2D
    packetLen = 16
    sliceLen = 10*60
    dbFile = None
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
    topoFile = None
    diameter = None

    fwdRawFile = open('/dev/null', 'w')
    fwdAggFile = open('/dev/null', 'w')
    ipiFile = open('/dev/null', 'w')

    if len(sys.argv) < 3:
        usage()
        sys.exit(1)
    (opt,val) = (sys.argv[1], sys.argv[2])
    if opt == '--dbTopo':
        dbFile = val
    elif opt == '--fileTopo':
        topoFile = val
    else:
        usage()

    if dbFile:
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
    
    for (opt, val) in zip(sys.argv, sys.argv[1:]):
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
        if opt == '--testsPerSetup':
            testsPerSetup = int(val)
        if opt == '--textOutFile':
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


    if dbFile:
        topo = TestbedTopology(dbFile, nsluFile, nodeFile, sr, txp,
          packetLen, sliceLen)
    else:
        topo = FileTopology(topoFile)

    if naive:
        sim = NaiveSimulation(topo)
    else:
        sim = PhySimulation(topo, captureThresh, noCaptureLoss,
          noCapMethod, synchLoss)
    for i in range(numSetups):
        print "Test setup %d of %d"%(i+1, numSetups) 
        sim.simFloodBatch([n for n in sim.G.nodes()], testsPerSetup) 
    #OK, so now we've got an  n x n x tps matrix of distance
    #  measurements

    #TODO: this should be a method of simulation class

    #TODO this is going to way underestimate diameter if it uses all
    # edges
    #diameter = nx.diameter(sim.G) 
    ipi = {}
    for n in sim.G.nodes():
        sim.G.node[n]['forwards'] = []
        ipi[n]=[]
    
    #ignore nodes with no edges, if they appear
    for n in range(selectionTrials):
        for s in sim.G.nodes():
            if s == dest or len(sim.G[s]) == 0:
                continue
            #pick d_sd from source measurements
            d_sd = dm.advertiseDistance(sim.G.node[s]['distances'][dest])
            ipi[s].append(d_sd )
            for f in sim.G.nodes():
                #no edges for this node in connectivity graph, ignore it
                if len(sim.G[f]) == 0:
                    continue
                if f == dest or f == s :
                    isForwarder = True
                else:
                    d_sf = dm.selectDistance(sim.G.node[f]['distances'][s])
                    d_fd = dm.selectDistance(sim.G.node[f]['distances'][dest])
                    isForwarder = (d_sf + d_fd) <= d_sd + bw
                sim.G.node[f]['forwards'].append((s,  isForwarder))

    diameter = 0
    for n in ipi:
        diameter = max( ipi[n] + [diameter])
    floodDuration = diameter + 1

    for f in sim.G.nodes():
        if f == dest or len(sim.G[f]) == 0:
            continue
        forwards = sim.G.node[f]['forwards']
        for (src, isForwarder) in forwards:
            #output: src, forwarder, isForwarder
            fwdRawFile.write('%d %d %d\n'%(src, f, isForwarder))
        totalTrials = len(forwards)
        activeTrials = len([ s for (s, isForwarder) in forwards if isForwarder ] )
        #output: src, active, total, fractionActive
        fwdAggFile.write('%d %d %d %0.4f\n'%(f, activeTrials, totalTrials,
          float(activeTrials)/totalTrials))
        ipis = ipi[f]
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
          sum(ipis)/float(len(ipis)),
          sum(eipi)/float(len(eipi)),
          floodDuration))

    if depthOutFile:
        sim.depthOutput(depthOutFile)
    if textOutFile:
        sim.textOutput(textOutFile)
