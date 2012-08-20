#!/usr/bin/env python
import matplotlib.pyplot as plt
import networkx as nx

def mapSetup(nsluFile='nslu_locations.txt', 
        nodeFile='node_map.txt',
        mapFile='map.png'):
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
                nodes[nodeId] = {'pos':nslus[nslu][port]}
            else:
                #TODO: log missing node error
                pass
    
    G = nx.DiGraph()
    G.add_nodes_from([(n, nodes[n]) for n in nodes])
    return G

def addPrrEdges(G, edgeFile='prr_links.csv', prr_threshold = 0.0):
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
                G.add_edge(int(r[0]), int(r[1]), prr=float(r[2]))

def computeSPs(G, root, unreachableVal=-1):
    """ """
    p = nx.single_source_shortest_path_length(G, root)
    
    #fill in unreachable node values
    maxDepth= max([v for v in p.values()])
    for nodeId in G.nodes():
        if nodeId not in p:
            p[nodeId] = unreachableVal
    return p

def drawCMapNodes(G, colors):
    """ Draw nodes of G, color with cmap"""
    nx.draw_networkx_nodes(G, 
      pos=nx.get_node_attributes(G, 'pos'),
      node_size=200,
      nodelist = G.nodes()
      , node_color=[colors[n] for n in G.nodes()]
      , cmap = plt.cm.hot
    )

def drawEdges(G, alpha=0.2):
    """Draw a set of edges on the graph."""
    #draw selected edges 
    nx.draw_networkx_edges(G,
      pos = nx.get_node_attributes(G, 'pos'),
      edgelist=G.edges(),
      arrows=False,
      alpha=0.2)

def drawLabels(G, labelMap=None):
    """Draw labels on nodes in graph (nodeId by default)"""
    nx.draw_networkx_labels(G, 
      pos=nx.get_node_attributes(G, 'pos'),
      font_size=10,
      labels=labelMap)

if __name__ == '__main__':
    G = mapSetup('nslu_locations.txt', 'node_map.txt', 'map.png')
    addPrrEdges(G, 'prr_links.csv', prr_threshold=0.95)
    sp = computeSPs(G, 0, -1)
    drawCMapNodes(G, sp)
    drawLabels(G, sp)
    drawEdges(G)
    #display the plot
    plt.show()


##example of using map of colors
#G.node[1]['color']='blue'
#
#colors = nx.get_node_attributes(G, 'color')
#defaultColor = 'red'
##draw specified nodes, extracting attributes as needed
#nx.draw_networkx_nodes(G, 
#  pos=nx.get_node_attributes(G, 'pos'),
#  node_size=20,
#  nodelist = nl,
#  node_color=[colors.get(n, defaultColor) for n in nl]
#)

##label by node id
#nx.draw_networkx_labels(G, 
#  pos=nx.get_node_attributes(G, 'pos'),
#  font_size=10
#)

