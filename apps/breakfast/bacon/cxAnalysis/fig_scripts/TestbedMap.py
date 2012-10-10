#!/usr/bin/env python
import matplotlib.pyplot as plt
import networkx as nx
import sqlite3
import sys
import random
from math import log
import pdb

class TestbedMap(object):
    def __init__(self, nsluFile='config/nslu_locations.txt', 
            nodeFile='config/node_map.txt',
            mapFile='static/floorplan.png',
            scriptDir=None):
        """Set up a floorplan map of testbed nodes"""
        if not scriptDir:
            scriptDir='/'.join(sys.argv[0].split('/')[:-1])
        scriptDir = scriptDir+'/'

        #add background image
        im = plt.imread(scriptDir+mapFile)
        implot = plt.imshow(im)
        
        #read NSLU locations
        f = open(scriptDir+nsluFile)
        nslus={}
        for l in f.readlines():
            if not l.startswith("#"):
                [nslu, port, x, y]  = [int(v) for v in l.split()]
                if nslu not in nslus:
                    nslus[nslu] = {}
                nslus[nslu][port] = (x,y)
        
        #read node-nslu mapping and get node locations
        nodes = {}
        f = open(scriptDir+nodeFile)
        for l in f.readlines():
            if not l.startswith("#"):
                [nslu, port, nodeId] = [int(v) for v in l.split()]
                if nslu in nslus:
                    nodes[nodeId] = {'pos':nslus[nslu][port], 'nslu':nslu}
                else:
                    #TODO: log missing node error
                    pass
        
        self.G = nx.DiGraph()
        self.G.add_nodes_from([(n, nodes[n]) for n in nodes])
        self.labelMap = None
        

    def drawCMapNodes(self, node_size, palette):
        """ Draw nodes, color according to palette/colorMap"""
        nx.draw_networkx_nodes(self.G, 
          pos=nx.get_node_attributes(self.G, 'pos'),
          node_size=node_size,
          nodelist = self.G.nodes()
          , node_color=[self.G.node[n][self.colAttr] for n in self.G.nodes()]
          , cmap = palette
          , linewidths = [self.G.node[n].get('linewidth', 1.0) 
              for n in self.G.nodes()]
        )

    def drawEdges(self, alpha=0.2):
        """Draw a set of edges on the graph."""
        nx.draw_networkx_edges(self.G,
          pos = nx.get_node_attributes(self.G, 'pos'),
          edgelist=self.G.edges(),
          arrows=False,
          alpha=0.2)
    
    def drawLabels(self):
        """Draw labels on nodes in graph (nodeId by default)"""
        nx.draw_networkx_labels(self.G, 
          pos=nx.get_node_attributes(self.G, 'pos'),
          font_size=10,
          labels=self.labelMap)

    def setAttr(self, attr, attrMap, defaultVal=None):
        #ugly: we want to have a way to enforce that every node has a
        #  value in this map.
        if defaultVal is not None:
            for n in self.G.nodes():
                if n not in attrMap:
                    attrMap[n] = defaultVal
        nx.set_node_attributes(self.G, attr, attrMap)
    
    def setColAttr(self, colAttr):
        self.colAttr = colAttr

    def setLabels(self, labelMap):
        self.labelMap = labelMap

    def addOutlined(self, nodeId, width):
        self.G.node[nodeId]['linewidth'] = width

    def draw(self, outFile=None, node_size=200, palette=plt.cm.jet):
        self.drawCMapNodes(node_size, palette)
        self.drawEdges()
        self.drawLabels()
        self.postDraw()
        if not outFile:
            plt.show()
        else:
            F = plt.gcf()
            F.set_size_inches([12, 12])
            plt.savefig(outFile, format='png')
            pass

    def postDraw(self):
        pass

    def textOutput(self):
        print 'node,%s'%self.colAttr
        for n in self.G.nodes():
            print '%d,%f'%(n, self.G.node[n][self.colAttr])

class SingleTXDepth(TestbedMap):
    def __init__(self, root, dbFile, sr, txp, packetLen,
          prr_threshold=0.0, rssi_threshold=-100, 
          distanceLabels = False, **kwargs):
        print root, dbFile, sr, txp, packetLen, prr_threshold, rssi_threshold, distanceLabels
        super(SingleTXDepth, self).__init__(**kwargs)
        self.loadPrrEdges(dbFile, sr, txp, packetLen, prr_threshold,
          rssi_threshold)
        self.distances = self.computeSPs(root)
        self.setAttr('distance', self.distances)
        self.setColAttr('distance')
        self.addOutlined(root, 10)
        if distanceLabels:
            self.setLabels(self.distances)

    def loadPrrEdges(self, dbFile, sr, txp, packetLen, prr_threshold,
          rssi_threshold):
        c = sqlite3.connect(dbFile)
        links = c.execute('SELECT src, dest, prr FROM link WHERE sr=?  AND txPower=? AND len=? AND prr >=? and avgRssi >=?', (sr,
          txp, packetLen, prr_threshold, rssi_threshold)).fetchall()
        for (src, dest, prr) in links:
            self.G.add_edge(src, dest, prr=prr)
    
    def computeSPs(self, root, unreachableVal=0):
        """Compute length of shortest paths from root to each other node"""
        p = nx.single_source_shortest_path_length(self.G, root)
        
        #fill in unreachable node values
        maxDepth= max([v for v in p.values()])
        for nodeId in self.G.nodes():
            if nodeId not in p:
                p[nodeId] = unreachableVal
        return p

class Degree(TestbedMap):
    def __init__(self, dbFile, sr, txp, packetLen, prr_threshold=0.0,
            degreeLabels = False, **kwargs):
        super(Degree, self).__init__(**kwargs)
        self.loadPrrEdges(dbFile, sr, txp, packetLen, prr_threshold)
        self.degrees = self.computeDegrees()
        self.setAttr('degree', self.degrees)
        self.setColAttr('degree')
        if degreeLabels:
            self.setLabels(self.degrees)

    def loadPrrEdges(self, dbFile, sr, txp, packetLen, prr_threshold):
        c = sqlite3.connect(dbFile)
        links = c.execute('SELECT src, dest, prr FROM link WHERE sr=? AND txPower=? AND len=? AND prr >=?', (sr, txp, packetLen, prr_threshold)).fetchall()
        for (src, dest, prr) in links:
            self.G.add_edge(src, dest, prr=prr)
    
    def computeDegrees(self):
        return self.G.in_degree()


class CXDistance(TestbedMap):
    def __init__(self, dbFile, node, distanceFrom, **kwargs):
        super(CXDistance, self).__init__(**kwargs)
        self.loadDistances(node, distanceFrom, dbFile)
        self.loadErrors(dbFile)
        self.setAttr('distance', self.distances, 0)
        self.setColAttr('distance')
        self.addOutlined(node, 10)

        for nodeId in self.errors:
            self.addOutlined(nodeId, 3)
        rounded = dict( [ (k, "%.1f"%self.distances[k]) 
          for k in self.distances])
        self.setLabels(rounded)

    def loadDistances(self, node, distanceFrom, dbFile):
        c = sqlite3.connect(dbFile)
        if distanceFrom:
            self.distances = dict(c.execute('SELECT dest, avgDepth FROM agg_depth WHERE src=?', (node,)))
        else:
            self.distances = dict(c.execute('SELECT src, avgDepth FROM agg_depth WHERE dest=?', (node,)))
        self.distances[node] = 0
        c.close()

    def loadErrors(self, dbFile):
        c = sqlite3.connect(dbFile)
        self.errors = [ nodeId for (nodeId,) in c.execute('SELECT node from error_events')]

class CXForwarders(TestbedMap):
    def __init__(self, src, dest, dbFile, **kwargs):
        super(CXForwarders, self).__init__(**kwargs)
        self.loadForwarders(src, dest, dbFile)
        self.loadErrors(dbFile)
        self.fwdRatio[src]=1.0
        self.fwdRatio[dest]=1.0
        self.setAttr('fwdRatio', self.fwdRatio, 0)
        self.setColAttr('fwdRatio')
        self.addOutlined(src, 10)
        self.addOutlined(dest, 10)
        for nodeId in self.errors:
            self.addOutlined(nodeId, 3)
        rounded = dict([ (k, "%.2f"%self.fwdRatio[k]) 
          for k in self.fwdRatio])
        self.setLabels(rounded)

    def loadForwarders(self, src, dest, dbFile):
        c = sqlite3.connect(dbFile)
        self.fwdRatio = dict(c.execute('SELECT fwd, avg(f) FROM routes where src=? and dest=? group by src, fwd, dest', (src, dest)))
        c.close()

    def loadErrors(self, dbFile):
        c = sqlite3.connect(dbFile)
        self.errors = [ nodeId for (nodeId,) in c.execute('SELECT node from error_events')]

class CXPrr(TestbedMap):
    def __init__(self, node, prrFrom, dbFile, **kwargs):
        super(CXPrr, self).__init__(**kwargs)
        self.loadPrrs(node, prrFrom, dbFile)
        self.loadErrors(dbFile)
        self.prrs[node]=1.0
        self.setAttr('prr', self.prrs, 0.0)
        self.setColAttr('prr')
        self.addOutlined(node, 10)
        for nodeId in self.errors:
            self.addOutlined(nodeId, 3)
        rounded = dict([ (k, "%.2f"%self.prrs[k]) 
          for k in self.prrs])
        self.setLabels(rounded)

    def loadPrrs(self, node, prrFrom, dbFile):
        c = sqlite3.connect(dbFile)
        if prrFrom:
            #weighted average of PR + non-PR packets
            q = 'SELECT dest, sum(cnt*prr)/sum(cnt) from prr_clean where src=? group by dest'
        else:
            q = 'SELECT src, sum(cnt*prr)/sum(cnt) from prr_clean where dest=? group by src'
#        print "Using query:",q, node
        self.prrs = dict(c.execute(q, (node,)))
        c.close()

    def loadErrors(self, dbFile):
        c = sqlite3.connect(dbFile)
        self.errors = [ nodeId for (nodeId,) in c.execute('SELECT node from error_events')]
        

class SinglePrr(TestbedMap):
    def __init__(self, nodeId, prrFrom, dbFile, **kwargs):
        super(SinglePrr, self).__init__(**kwargs)
        self.loadPrrs(nodeId, prrFrom, dbFile)
        self.prrs[nodeId]=1.0
        self.setAttr('prr', self.prrs, 0.0)
        self.setColAttr('prr')
        self.addOutlined(nodeId, 10)
        rounded = dict([ (k, "%.2f"%self.prrs[k]) 
          for k in self.prrs])
        self.setLabels(rounded)

    def loadPrrs(self, nodeId, prrFrom, dbFile):
        c = sqlite3.connect(dbFile)
        if prrFrom:
            q = 'SELECT dest, prr from link where src=?'
        else:
            q = 'SELECT src, prr from link where dest=?'
        self.prrs = dict(c.execute(q, (nodeId,)))
        c.close()

class FloodSimMap(TestbedMap):
    def __init__(self, connDbFile, root=0, maxDepth=10, simRuns=100,
          sr=125, txp=0x8D, packetLen=35, captureThresh=6,
          noCaptureLoss=0.3, independent=0, colorMode=None, **kwargs):
        super(FloodSimMap, self).__init__(**kwargs)
        self.root=root
        self.dbFile = connDbFile
        self.sr=sr
        self.txp=txp
        self.packetLen=packetLen
        self.captureThresh = captureThresh
        self.noCaptureLoss = noCaptureLoss
        self.simMultiple(root, independent, maxDepth, simRuns,
          testSetups, dbFile)
        if colorMode == 'distance':
            self.computeDepth()
            self.setColAttr('distance')
            self.addOutlined(root, 10)
            self.setLabels(nx.get_node_attributes(self.G, 'distance'))
        if colorMode == 'prr':
            self.computePrr()
            self.setColAttr('prr')
            self.addOutlined(root, 10)
            self.setLabels(nx.get_node_attributes(self.G, 'prr'))

    def textOutput(self):
        print "src,dest,sn,depth"
        for n in self.G.nodes():
            for (i, d) in enumerate(self.G.node[n]['simResults']):
                if (d != sys.maxint):
                    print '%d,%d,%d,%d'%(self.root, n, i, d)

    def loadEdges(self, dbFile, sr, txp, packetLen):
        c = sqlite3.connect(dbFile)
        links = c.execute('SELECT src, dest, prr, avgRssi FROM link WHERE sr=? AND txPower=? AND len=?', (sr, txp, packetLen)).fetchall()
        for (src, dest, prr, rssi) in links:
            self.G.add_edge(src, dest, prr=prr, rssi=rssi)
    
    def simInit(self, root):
        for n in self.G.nodes():
            self.G.node[n]['receiveRound'] = sys.maxint
            if 'simResults' not in self.G.node[n]:
                self.G.node[n]['simResults'] = []
        self.G.node[root]['receiveRound'] = 0

    def computePrr(self):
        for n in self.G.nodes():
            r_all = self.G.node[n]['simResults']
            r_rx  = [v for v in r_all if v != sys.maxint]
            prr = len(r_rx)/float(len(r_all))
            self.G.node[n]['prr'] = prr

    def computeDepth(self):
        for n in self.G.nodes():
            r_all = self.G.node[n]['simResults']
            r_rx  = [v for v in r_all if v != sys.maxint]
            prr = len(r_rx)/float(len(r_all))
            if not r_rx:
                self.G.node[n]['distance'] = 0
            else:
                self.G.node[n]['distance'] = sum(r_rx)/float(len(r_rx))

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

    def simRoundReverse(self, d):
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
            if len(incoming) > 1:
                combinedRSSI = self.addRSSIs([rssi for (prr, rssi) in incoming])
                for (prr, rssi) in incoming:
                    if rssi > self.subtractRSSI(combinedRSSI, rssi) + self.captureThresh:
                        capturePresent = True
                        maxPrr = prr
                shouldReceive = (random.random() < maxPrr)
            else:
                capturePresent = True
                shouldReceive = (random.random() < maxPrr)

            if not capturePresent and shouldReceive:
                shouldReceive = (random.random() > self.noCaptureLoss)
            if shouldReceive:
                self.G.node[n]['receiveRound'] = d

    def simRound(self, d):
        for n in self.G.nodes():
            if self.G.node[n]['receiveRound'] == d-1:
                for dest in self.G[n]:
                    if self.G.node[dest]['receiveRound'] == sys.maxint: 
                        if random.random() < self.G[n][dest]['prr']:
                            self.G.node[dest]['receiveRound'] = d
                        else:
                            pass

    def sim(self, root, independent, maxDepth=10):
        self.simInit(root)
        for d in range(1, maxDepth+1):
            if independent:
                self.simRound(d)
            else:
                self.simRoundReverse(d)
        for n in self.G.nodes():
            self.G.node[n]['simResults'].append(self.G.node[n]['receiveRound'])
 
    def simMultiple(self, root, independent, maxDepth=10, simRuns=100,
            testSetups=10):
        for k in range(testSetups):
            (start, end) = randomTimeSlice(600)
            self.loadEdgesTimeSlice(start, end)
            for i in range(simRuns/testSetups):
                self.sim(root, independent, maxDepth)
    
    def randomTimeSlice(self):
        c = sqlite3.connect(self.dbFile)
        [(start, end)] = c.execute('''SELECT min(ts), max(ts) 
            from tx 
            where src = 2 and txpower = ? and sr=? and len=? 
            group by src, txpower, sr, len''', 
          (self.txp, self.sr, self.packetLen)).fetchall()
        end -= sliceLen
        startSlice = start + (random.random() * (end - start))
        return (startSlice, startSlice + sliceLen)

    def loadEdgesTimeSlice(self, startTime, endTime):
        self.G.remove_edges_from(self.G.edges())
        c = sqlite3.connect(self.dbFile)
        c.execute('''DROP TABLE IF EXISTS TXO_TMP''')
        c.execute('''CREATE TEMPORARY TABLE TXO_TMP
                     AS 
                     SELECT * from TXO 
                     WHERE sr=? and txpower=? and len=?
                     WHERE ts between ? and ?''', 
                     (self.sr, self.txpower, 
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
        for (src, dest, prr, rssi, lqi) in links:
            self.G.add_edge(src, dest, prr=prr, rssi=rssi)

#     def listResults(self):
#         for n in self.G.nodes():
#             r_all = self.G.node[n]['simResults']
#             r_rx  = [v for v in r_all if v != sys.maxint]
#             prr = len(r_rx)/float(len(r_all))
#             if prr > 0:
#                 avgDepth = sum(r_rx)/float(len(r_rx))
#                 print n, avgDepth, prr


class DutyCycle(TestbedMap):
    def __init__(self, dbFile, dcLabels, **kwargs):
        super(DutyCycle, self).__init__(**kwargs)
        self.loadDutyCycles(dbFile)
        self.setAttr('dutyCycle', self.dutyCycles, 0.0)
        self.setColAttr('dutyCycle')
        if dcLabels:
          rounded = dict([ (k, "%.2f"%self.dutyCycles[k]) 
            for k in self.dutyCycles])
          self.setLabels(rounded)

    def loadDutyCycles(self, dbFile):
        c = sqlite3.connect(dbFile)
        q = 'SELECT node, dc from duty_cycle'
        self.dutyCycles = dict(c.execute(q))
        c.close()

class ConditionalPrr(TestbedMap):
    def __init__(self, dbFile, refNode, prrLabels, **kwargs):
        super(ConditionalPrr, self).__init__(**kwargs)
        self.loadPrrs(dbFile, refNode)
        self.loadTransmitters(dbFile)
        self.addOutlined(refNode, 10)
        self.setAttr('prr', self.prrs, 0.0)
        self.setColAttr('prr')
        if prrLabels:
            rounded = dict([ (k, "%.2f"%self.prrs[k]) 
              for k in self.prrs])
            self.setLabels(rounded)
        for (t,) in self.transmitters:
            self.addOutlined(t, 5)

    def loadPrrs(self, dbFile, refNode):
        c = sqlite3.connect(dbFile)
        q = 'SELECT cd, condPrr from conditional_prr WHERE rd=?'
        self.prrs = dict(c.execute(q,(refNode,)))

    def loadTransmitters(self, dbFile):
        c = sqlite3.connect(dbFile)
        q = 'SELECT distinct(src) from transmits'
        self.transmitters = c.execute(q)

class Trace(TestbedMap):
    def __init__(self, dbFile, src, sn, count, **kwargs):
        super(Trace, self).__init__(**kwargs)
        self.loadStates(dbFile, src, sn, count)
        
        key = {}
        key[70] = {'pos': (0, 100)}
        key[71] = {'pos': (0, 200)}
        key[72] = {'pos': (0, 300)}
        key[73] = {'pos': (0, 400)}
        key[74] = {'pos': (0, 500)}
        self.states[70] = 0
        self.states[71] = 1
        self.states[72] = 2
        self.states[73] = 3
        self.states[74] = 4
        
        labels = {}
        for n in self.states:
            labels[n] = [".", "T", "R", "P", "!"][self.states[n]]
        self.setLabels(labels)
        self.G.add_nodes_from([(k, key[k]) for k in key])
        self.setAttr('state', self.states, 0)
        self.setColAttr('state')
        

    def loadStates(self, dbFile, src, sn, count):
        c = sqlite3.connect(dbFile)
        q = '''SELECT cn, fn FROM link_tx where src=? and sn=? and hc=1'''
        r = c.execute(q, (src, sn)).fetchone()
        (cn, firstFN) = r

        q = '''SELECT sender, 1 as label FROM link_tx WHERE cn=? and fn=? and sn=?'''
        self.sending = dict(c.execute(q,(cn, firstFN+count, sn)))
        
        #end of this transmission
        if not self.sending:
            q = '''SELECT node FROM fwd where cn=? and src=? and f=1'''
            for (node,) in c.execute(q,(cn,src)):
                self.addOutlined(node, 5)
            self.states = {}
            return

        q = '''SELECT receiver, 2 as label FROM link_rx WHERE cn=? and fn=?'''
        self.receiving = dict(c.execute(q,(cn, firstFN+count)))
        
        q = '''SELECT distinct sender, 3 as label
          FROM link_tx 
          WHERE cn=? and src=? and sn=? 
            and fn < ?'''
        self.sent = dict(c.execute(q, (cn, src, sn, firstFN+count)))

        q = '''SELECT distinct sender, 4 as label
          FROM link_tx
          WHERE cn=? and src=? and sn!=? and fn=?'''
        self.conflict = dict(c.execute(q, (cn, src, sn,
          firstFN+count)))
        self.states = dict(self.sending.items() 
          + self.receiving.items() 
          + self.sent.items()
          + self.conflict.items())
        q = '''SELECT node FROM fwd where cn=? and src=? and f=1'''
        for (node,) in c.execute(q,(cn,src)):
            self.addOutlined(node, 5)

        
if __name__ == '__main__':
    fn = sys.argv[1]
    t = sys.argv[2]
    if t == '--simple':
        src = 0
        prrThresh = 0.95
        rssiThresh = -100
        sr = 125
        #0x8D= 0
        txp = 0x8D
        packetLen = 35
        distanceLabels = False
        for (o, v) in zip(sys.argv[2:], sys.argv[3:]):
            if o == '--src':
                src = int(v)
            if o == '--prrThresh':
                prrThresh = float(v)
            if o == '--rssiThresh':
                rssiThresh = float(v)
            if o == '--sr':
                sr = int(v)
            if o == '--txp':
                txp = int(v, 16)
            if o == '--pl':
                pl = int(v)
            if o == '--distanceLabels':
                distanceLabels = int(v)
        print distanceLabels
        tbm = SingleTXDepth(src, fn, sr, txp, packetLen, prrThresh,
          rssiThresh, distanceLabels)
    elif t == '--cxd':
        distanceFrom = True
        nodeId = 0
        for (o, v) in zip(sys.argv[2:], sys.argv[3:]):
            if o == '--from':
                distanceFrom = True
                nodeId = int(v)
            if o == '--to':
                distanceFrom = False
                nodeId = int(v)
        tbm = CXDistance(fn, nodeId, distanceFrom)
    elif t == '--cxf':
        src = int(sys.argv[3])
        dest = int(sys.argv[4])
        tbm = CXForwarders(src, dest, fn)
    elif t == '--cxp':
        prrFrom = True
        nodeId = 0
        for (o, v) in zip(sys.argv[2:], sys.argv[3:]):
            if o == '--from':
                prrFrom = True
                nodeId = int(v)
            if o == '--to':
                prrFrom = False
                nodeId = int(v)
        tbm = CXPrr(nodeId, prrFrom, fn)
    elif t == '--sp':
        prrFrom = True
        nodeId = 0
        for (o, v) in zip(sys.argv[2:], sys.argv[3:]):
            if o == '--from':
                prrFrom = True
                nodeId = int(v)
            if o == '--to':
                prrFrom = False
                nodeId = int(v)
        tbm = SinglePrr(nodeId, prrFrom, fn)
    elif t == '--dc':
        dcLabels = 1
        if len(sys.argv) > 4:
            for (o, v) in zip(sys.argv[3:], sys.argv[4:]):
                if o == '--dcLabels':
                    dcLabels = int(v)
        tbm = DutyCycle(fn, dcLabels)
    elif t == '--degree':
        thresh = 0.95
        sr = 125
        txp = 0x8D
        packetLen = 35
        degreeLabels = False
        if len(sys.argv) > 4:
            for (o, v) in zip(sys.argv[3:], sys.argv[4:]):
                if o == '--thresh':
                    thresh = float(v)
                if o == '--sr':
                    sr = int(v)
                if o == '--txp':
                    txp = int(v, 16)
                if o == '--pl':
                    pl = int(v)
                if o == '--degreeLabels':
                    degreeLabels = int(v)
        tbm = Degree(fn, sr, txp, packetLen, thresh,
          degreeLabels)
    elif t == '--fsp':
        root = 0
        maxDepth = 10
        simRuns = 100
        sr = 125
        txp = 0x8D
        packetLen = 35
        tbm = FloodSimMap(fn, root, maxDepth, simRuns, sr, txp,
            packetLen, colorMode='prr')
    elif t == '--fsd':
        root = 0
        maxDepth = 10
        simRuns = 100
        sr = 125
        txp = 0x8D
        packetLen = 35
        tbm = FloodSimMap(fn, root, maxDepth, simRuns, sr, txp,
            packetLen, colorMode='distance')
    elif t == '--sim':
        root = 0
        maxDepth = 10
        simRuns = 1
        sr = 125
        txp = 0x8D
        packetLen = 35
        captureThresh = 0.0
        noCaptureLoss = 0.0
        colorMode = 'distance'
        independent = 1
        if (len(sys.argv) > 4):
            for (o, v) in zip(sys.argv[3:], sys.argv[4:]):
                if o == '--root':
                    root = int(v)
                if o == '--simRuns':
                    simRuns = int(v)
                if o == '--captureThresh':
                    captureThresh = float(v)
                if o == '--noCaptureLoss':
                    noCaptureLoss = float(v)
                if o == '--colorMode':
                    colorMode = v
                if o == '--independent':
                    independent = int(v)
        tbm = FloodSimMap(fn, root, maxDepth, simRuns, sr, txp,
          packetLen, captureThresh, noCaptureLoss, independent, 
          colorMode)
    elif t == '--cond':
        refNode = 2
        prrLabels = 1
        if (len(sys.argv)>4):
            for (o, v) in zip(sys.argv[3:], sys.argv[4:]):
                if o == '--ref':
                    refNode = int(v)
                if o == '--prrLabels':
                    prrLabels = int(v)
        tbm = ConditionalPrr(fn, refNode, prrLabels)
    elif t == '--trace':
        src = 0
        sn = 1
        count = 0
        if (len(sys.argv) > 4):
            for (o, v) in zip(sys.argv[3:], sys.argv[4:]):
                if o == '--src':
                    src = int(v)
                if o == '--sn':
                    sn = int(v)
                if o == '--count':
                    count = int(v)
        tbm = Trace(fn, src, sn, count)
    else:
        print >> sys.stderr, "Unrecognized type",t

    outFile=None
    for (o, v) in zip(sys.argv, sys.argv[1:]):
        if o == '--outFile':
            outFile = v
    tbm.draw(node_size=400, outFile=outFile)
    if '--text' in sys.argv:
        tbm.textOutput()

# x CX trace
#   - no edges
#   - burst setup info to gray out non-forwarders
#   - for each frame in transmission, color as:
#     - received this frame
#     - sent this frame
#     - sent in some earlier frame of this burst
