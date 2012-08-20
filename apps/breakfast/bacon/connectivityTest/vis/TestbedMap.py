#!/usr/bin/env python
import matplotlib.pyplot as plt
import networkx as nx
import sqlite3
import sys

class TestbedMap(object):
    def __init__(self, nsluFile='nslu_locations.txt', 
            nodeFile='node_map.txt',
            mapFile='floorplan.png'):
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
            #TODO: file output
            pass

    def postDraw(self):
        pass

class SingleTXDepth(TestbedMap):
    def __init__(self, root, edgeFile, prr_threshold=0.0,
            distanceLabels = False, **kwargs):
        super(SingleTXDepth, self).__init__(*kwargs)
        self.addPrrEdges(edgeFile, prr_threshold)
        self.distances = self.computeSPs(root)
        self.setAttr('distance', self.distances)
        self.setColAttr('distance')
        self.addOutlined(root, 3)
        if distanceLabels:
            self.setLabels(self.distances)

    def addPrrEdges(self, edgeFile, prr_threshold):
        """ Add edges to a graph from PRR file, where PRR is above some
        threshold. Lines in file should be formatted as: 
    
        src,dest,prr
    
        By default, all edges are added (prr threshold is 0.0)
        """
        f = open(edgeFile)
        for l in f.readlines():
            if not l.startswith("#"):
                r = l.split(',')
                if float(r[2]) >= prr_threshold:
                    self.G.add_edge(int(r[0]), int(r[1]), prr=float(r[2]))
    
    def computeSPs(self, root, unreachableVal=-1):
        """Compute length of shortest paths from root to each other node"""
        p = nx.single_source_shortest_path_length(self.G, root)
        
        #fill in unreachable node values
        maxDepth= max([v for v in p.values()])
        for nodeId in self.G.nodes():
            if nodeId not in p:
                p[nodeId] = unreachableVal
        return p

class CXDistance(TestbedMap):
    def __init__(self, root, distanceFile, **kwargs):
        super(CXDistance, self).__init__(*kwargs)
        self.loadDistances(root, distanceFile)
        self.setAttr('distance', self.distances)
        self.setColAttr('distance')

        rounded = dict( [ (k, "%.1f"%self.distances[k]) 
          for k in self.distances])
        self.setLabels(rounded)

    def loadDistances(self, root, distanceFile, unreachableVal=-1):
        self.distances={}
        f = open(distanceFile, 'r')
        for l in f.readlines():
            r = l.split(',')
            if int(r[0]) == root:
                self.distances[int(r[1])] = float(r[2])
        self.distances[root] = 0
        for nodeId in self.G.nodes():
            if nodeId not in self.distances:
                self.distances[nodeId] = unreachableVal

class CXForwarders(TestbedMap):
    def __init__(self, src, dest, dbFile, **kwargs):
        super(CXForwarders, self).__init__(*kwargs)
        self.loadForwarders(src, dest, dbFile)
        self.fwdRatio[src]=1.0
        self.fwdRatio[dest]=1.0
        self.setAttr('fwdRatio', self.fwdRatio, 0)
        self.setColAttr('fwdRatio')
        self.addOutlined(src, 3)
        self.addOutlined(dest, 3)
        rounded = dict([ (k, "%.2f"%self.fwdRatio[k]) 
          for k in self.fwdRatio])
        self.setLabels(rounded)

    def loadForwarders(self, src, dest, dbFile):
        c = sqlite3.connect(dbFile)
        self.fwdRatio = dict(c.execute('SELECT fwd, avg(f) FROM routes where src=? and dest=? group by src, fwd, dest', (src, dest)))
        c.close()

class CXPrr(TestbedMap):
    def __init__(self, src, dbFile, **kwargs):
        super(CXPrr, self).__init__(*kwargs)
        self.loadPrrs(src, dbFile)
        self.prrs[src]=1.0
        self.setAttr('prr', self.prrs, 0.0)
        self.setColAttr('prr')
        self.addOutlined(src, 3)
        rounded = dict([ (k, "%.2f"%self.prrs[k]) 
          for k in self.prrs])
        self.setLabels(rounded)

    def loadPrrs(self, src, dbFile):
        c = sqlite3.connect(dbFile)
        self.prrs = dict(c.execute('SELECT dest, prr from prr_no_startup where src=?', (src,)))
        c.close()

class SinglePrr(TestbedMap):
    def __init__(self, src, dbFile, **kwargs):
        super(SinglePrr, self).__init__(*kwargs)
        self.loadPrrs(src, dbFile)
        self.prrs[src]=1.0
        self.setAttr('prr', self.prrs, 0.0)
        self.setColAttr('prr')
        self.addOutlined(src, 3)
        rounded = dict([ (k, "%.2f"%self.prrs[k]) 
          for k in self.prrs])
        self.setLabels(rounded)

    def loadPrrs(self, src, dbFile):
        c = sqlite3.connect(dbFile)
        self.prrs = dict(c.execute('SELECT dest, prr from link where src=?', (src,)))
        c.close()
        
if __name__ == '__main__':
    t = sys.argv[1]
    if t == '--simple':
        src = int(sys.argv[2])
        tbm = SingleTXDepth(src, 'prr_links.csv', 0.95)
    elif t == '--cxd':
        tbm = CXDistance(0, 'cxDepth.csv')
    elif t == '--cxf':
        src = int(sys.argv[2])
        dest = int(sys.argv[3])
        fn = sys.argv[4]
        tbm = CXForwarders(src, dest, fn)
    elif t == '--cxp':
        src = int(sys.argv[2])
        fn = sys.argv[3]
        tbm = CXPrr(src, fn)
    elif t == '--sp':
        src = int(sys.argv[2])
        fn = sys.argv[3]
        tbm = SinglePrr(src, fn)
    tbm.draw(node_size=400)

# - common internal state: Graph, edges, labels, colors
# - common behavior: construct, draw (to file or screen)
# - subclasses define rules for what constitutes edge, label, color.
# x single-tx connectivity subclass:
#   - edges are PRR > threshold
#   - label is depth
#   - color is depth
# x CX distance subclass
#   - no edges
#   - label is depth
#   - color is depth
# x CX forwarder rates
#   - no edges
#   - color for src, dest fixed
#   - other nodes: fraction of bursts for which node is forwarder
#   - label is node id?
# 0 CX PRR
#   - no edges
#   - color is PRR (mark source)
#   - label is node ID
# 0 CX trace
#   - no edges
#   - burst setup info to gray out non-forwarders
#   - for each frame in transmission, color as:
#     - received this frame
#     - sent this frame
#     - sent in some earlier frame of this burst
