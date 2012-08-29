#!/usr/bin/env python
import matplotlib.pyplot as plt
import networkx as nx
import sqlite3
import sys

class TestbedMap(object):
    def __init__(self, nsluFile='config/nslu_locations.txt', 
            nodeFile='config/node_map.txt',
            mapFile='static/floorplan.png'):
        """Set up a floorplan map of testbed nodes"""
        #add background image
        im = plt.imread(mapFile)
        implot = plt.imshow(im)
        
        #read NSLU locations
        f = open(nsluFile)
        nslus={}
        for l in f.readlines():
            if not l.startswith("#"):
                [nslu, port, x, y]  = [int(v) for v in l.split()]
                if nslu not in nslus:
                    nslus[nslu] = {}
                nslus[nslu][port] = (x,y)
        
        #read node-nslu mapping and get node locations
        nodes = {}
        f = open(nodeFile)
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

class SingleTXDepth(TestbedMap):
    def __init__(self, root, dbFile, sr, txp, packetLen, prr_threshold=0.0,
            distanceLabels = False, **kwargs):
        super(SingleTXDepth, self).__init__(**kwargs)
        self.loadPrrEdges(dbFile, sr, txp, packetLen, prr_threshold)
        self.distances = self.computeSPs(root)
        self.setAttr('distance', self.distances)
        self.setColAttr('distance')
        self.addOutlined(root, 10)
        if distanceLabels:
            self.setLabels(self.distances)

    def loadPrrEdges(self, dbFile, sr, txp, packetLen, prr_threshold):
        c = sqlite3.connect(dbFile)
        links = c.execute('SELECT src, dest, prr FROM link WHERE sr=? AND txPower=? AND len=? AND prr >=?', (sr, txp, packetLen, prr_threshold)).fetchall()
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
        self.setAttr('distance', self.distances, -1)
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
        print "Using query:",q, node
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

class DutyCycle(TestbedMap):
    def __init__(self, dbFile, **kwargs):
        super(DutyCycle, self).__init__(**kwargs)
        self.loadDutyCycles(dbFile)
        self.setAttr('dutyCycle', self.dutyCycles, 0.0)
        self.setColAttr('dutyCycle')
        rounded = dict([ (k, "%.2f"%self.dutyCycles[k]) 
          for k in self.dutyCycles])
        self.setLabels(rounded)

    def loadDutyCycles(self, dbFile):
        c = sqlite3.connect(dbFile)
        q = 'SELECT node, dc from duty_cycle'
        self.dutyCycles = dict(c.execute(q))
        c.close()
        
if __name__ == '__main__':
    fn = sys.argv[1]
    t = sys.argv[2]
    if t == '--simple':
        src = int(sys.argv[3])
        thresh = float(sys.argv[4])
        sr = 125
        #0xC3= +10
        txp = 0xC3
        packetLen = 35
        distanceLabels = False
        if len(sys.argv) > 5:
            for (o, v) in zip(sys.argv[5:], sys.argv[6:]):
                if o == '--sr':
                    sr = int(v)
                if o == '--txp':
                    txp = int(v, 16)
                if o == '--pl':
                    pl = int(v)
                if o == '--distanceLabels':
                    distanceLabels = int(v)
        tbm = SingleTXDepth(src, fn, sr, txp, packetLen, thresh,
          distanceLabels)
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
        tbm = DutyCycle(fn)
    elif t == '--degree':
        thresh = 0.95
        sr = 125
        #0xC3= +10
        txp = 0xC3
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
    else:
        print >> sys.stderr, "Unrecognized type",t

    outFile=None
    for (o, v) in zip(sys.argv, sys.argv[1:]):
        if o == '--outFile':
            outFile = v
    tbm.draw(node_size=400, outFile=outFile)

# 0 CX trace
#   - no edges
#   - burst setup info to gray out non-forwarders
#   - for each frame in transmission, color as:
#     - received this frame
#     - sent this frame
#     - sent in some earlier frame of this burst
