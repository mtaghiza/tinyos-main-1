#!/usr/bin/env python
import matplotlib.pyplot as plt
import networkx as nx

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

    def drawCMapNodes(self):
        """ Draw nodes, color according to palette/colorMap"""
        nx.draw_networkx_nodes(self.G, 
          pos=nx.get_node_attributes(self.G, 'pos'),
          node_size=200,
          nodelist = self.G.nodes()
          , node_color=[self.colorMap[n] for n in self.G.nodes()]
          , cmap = self.palette
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

    def setColors(self, colorMap, palette=None):
        self.colorMap = colorMap
        self.palette = palette

    def setLabels(self, labelMap):
        self.labelMap = labelMap

    def draw(self, outFile=None):
        self.drawCMapNodes()
        self.drawEdges()
        self.drawLabels()
        if not outFile:
            plt.show()
        else:
            #TODO: file output
            pass

class SingleTXDepth(TestbedMap):
    def __init__(self, root, edgeFile, prr_threshold=0.0, **kwargs):
        super(SingleTXDepth, self).__init__(*kwargs)
        self.addPrrEdges(edgeFile, prr_threshold)
        self.depths = self.computeSPs(root)
        self.setColors(self.depths, plt.cm.hot)
        self.setLabels(self.depths)

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
        """ """
        p = nx.single_source_shortest_path_length(self.G, root)
        
        #fill in unreachable node values
        maxDepth= max([v for v in p.values()])
        for nodeId in self.G.nodes():
            if nodeId not in p:
                p[nodeId] = unreachableVal
        return p

if __name__ == '__main__':
    tbm = SingleTXDepth(0, 'prr_links.csv', 0.95)
    tbm.draw()

#TODO: OO-ify
# - common internal state: Graph, edges, labels, colors
# - common behavior: construct, draw (to file or screen)
# - subclasses define rules for what constitutes edge, label, color.
# x single-tx connectivity subclass:
#   - edges are PRR > threshold
#   - label is depth
#   - color is depth
# - CX distance subclass
#   - no edges
#   - label is depth
#   - color is depth
# - CX forwarder rates
#   - no edges
#   - color for src, dest fixed
#   - other nodes: fraction of bursts for which node is forwarder
#   - label is node id?
# - CX PRR
#   - no edges
#   - color is PRR (mark source)
#   - label is node ID
# - CX trace
#   - no edges
#   - burst setup info to gray out non-forwarders
#   - for each frame in transmission, color as:
#     - received this frame
#     - sent this frame
#     - sent in some earlier frame of this burst
