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

class RoutingTable(object):
    def __init__(self, nodeId):
        self.nodeId = nodeId
        self.rt = {}

    def addEntry(self, src, dest, dist):
        pass

    def updateEntry(self, src, dest, dist):
        pass

    def isBetween(self, src, dest, bw):
        return False

    def getEntry(self, src, dest):
        if (src, dest) in self.rt:
            return self.rt[(src, dest)]
        elif (dest, src) in self.rt:
            return self.rt[(dest, src)]
        else:
            return None

    def getAdvertisedDistance(self, src, dest):
        return None
        

class LastRoutingTable(RoutingTable):
    def __init__(self, nodeId):
        super(self, RoutingTable).__init__(nodeId)

    def addEntry(self, src, dest, dist):
        self.rt[(src, dest)] = dist

    def updateEntry(self, src, dest, dist):
        self.addEntry(src, dest, dist)

    def isBetween(self, src, dest, bw):
        if self.nodeId in [src, dest]:
            return True
        sd = self.getEntry(src, dest)
        sf = self.getEntry(src, self.nodeId)
        fd = self.getEntry(self.nodeId, dest)
        if not all([sd, sf, fd]):
            return False
        return (sf + fd ) <= (sd + bw)

    def getAdvertisedDistance(self, src, dest):
        if self.nodeId in [src, dest]:
            return 0
        else:
            dist = self.getEntry(src, dest)
            if dist is not None:
                return dist
            else:
                return sys.maxint

class MaxRoutingTable(RoutingTable):
    def __init__(self, nodeId):
        super(self, RoutingTable).__init__(nodeId)

    def addEntry(self, src, dest, dist):
        self.rt[(src, dest)] = (dist, dist)

    def updateEntry(self, src, dest, dist):
        (minDist, maxDist) = self.rt.get((src, dest), (sys.maxint, 0))
        if dist < minDist:
            minDist = dist
        if dist > maxDist:
            maxDist = dist
        self.rt[(src, dest)] = (minDist, maxDist)
    
    def isBetween(self, src, dest, bw):
        if self.nodeId in [src, dest]:
            return True
        sdt = self.getEntry(src, dest)
        sft = self.getEntry(src, self.nodeId)
        fdt = self.getEntry(self.nodeId, dest)
        if not all([sdt, sft, fdt]):
            return False
        sd = sdt[1]
        sf = sft[0]
        fd = fdt[0]
        return (sf + fd ) <= (sd + bw)

    def getAdvertisedDistance(self, src, dest):
        if self.nodeId in [src, dest]:
            return 0
        else:
            dist = self.getEntry(src, dest)
            if dist:
                (minDist, maxDist) = dist
                return maxDist
            else:
                return sys.maxint

class AverageRoutingTable(RoutingTable):
    def __init__(self, nodeId):
        super(self, RoutingTable).__init__(nodeId)

    def addEntry(self, src, dest, dist):
        self.rt[(src, dest)] = [dist]

    def updateEntry(self, src, dest, dist):
        darr = self.rt.get( (src, dest), [])
        self.rt[(src, dest)] = darr + [dist]

    def isBetween(self, src, dest, bw):
        if self.nodeId in [src, dest]:
            return True
        sdt = self.getEntry(src, dest)
        sft = self.getEntry(src, self.nodeId)
        fdt = self.getEntry(self.nodeId, dest)
        if not all([sdt, sft, fdt]):
            return False
        sd = sum(sdt)/float(len(sdt))
        sf = sum(sft)/float(len(sft))
        fd = sum(fdt)/float(len(fdt))
        return (sf + fd) <= (sd + bw)

    def getAdvertisedDistance(self, src, dest):
        if self.nodeId in [src, dest]:
            return 0
        else:
            dist = self.getEntry(src, dest)
            if dist:
                return sum(dist)/float(len(dist))
            else:
                return sys.maxint

class RTFactory(object):
    def __init__(self):
        pass

    def newRT(self, node):
        return RoutingTable(node)

class LastRTFactory(RTFactory):
    def __init__(self):
        pass

    def newRT(self, node):
        return LastRoutingTable(node)

class AverageRTFactory(RTFactory):
    def __init__(self):
        pass

    def newRT(self, node):
        return AverageRoutingTable(node)

class MaxRTFactory(RTFactory):
    def __init__(self):
        pass

    def newRT(self, node):
        return MaxRoutingTable(node)

class Simulation(object):
    def __init__(self, topo, rtFactory):
        '''Create basic data structures and load nodes from topo. '''
        self.G = nx.DiGraph()
        self.topo = topo
        self.maxDepth = 10
        self.G.add_nodes_from(self.topo.getNodes())
        self.rtFactory = rtFactory
        self.initializeNodes()
        #TODO: move to params
        self.ipi = 60
        self.frameLen = 4e-3
        self.framesPerSlot = 40
        self.inactiveSlots = 5
        self.slots = len(self.G) + self.inactiveSlots
        self.firstInactive = len(self.G)
        self.cycleLen = self.slots * self.framesPerSlot
    
    def initializeNodes(self):
        for node in self.G:
            self.G[node]['rt'] = self.rtFactory.newRT(node)
            self.G[node]['queue'] = []
            self.G[node]['radio'] = 'off'
            if node != 0:
                self.G[node]['nextPacket'] = (random.random() * self.ipi) + self.ipi /2
   
    def simLoop(self, numCycles):
        self.simTime = 0
        for self.cycleNum in range(self.numCycles):
            for self.slotNum in range(self.slots):
                self.simSlot()

    def simSlot(self):
        #zero out received-this-slot for nodes
        for node in self.G:
            self.G[node]['rts'] = 0

        if self.slotNum in self.G:
            self.owner = self.G[self.slotNum]
            self.owner['clearTime'] = 0
            if self.slotNum == 0:
                self.owner['queue'] = ['schedule']
            else:
                #check for whether slot owner has data to send
                if len(self.owner['queue']) >= self.sendThresh:
                    if self.rrBurst:
                        ad = self.boundaryWidth + self.owner['rt'].getAdvertisedDistance(self.slotNum, 0)
                        self.owner['distance'] = ad
                        self.owner['queue'] = ['setup'] + self.owner['queue']
                else:
                    self.owner['pending'] = None
            radioState = 'idle'
        else:
            radioState = 'off'

        for node in self.G:
            self.G[node]['radio'] = radioState
        
        #iterate over the frames in this slot
        for self.frameOfSlot in range(self.framesPerSlot):
            self.frameNum = (self.framesPerSlot * self.slotNum) + self.frameOfSlot
            self.simTime += self.frameLen
            simFrame()
        #reset owner to idle
        self.owner['routingState'] = 'idle'
        #TODO: log duty cycle output

    def simFrame(self):
        self.updateQueues()
        
        #turn off nodes if they haven't received data
        #  yet in this slot and frameOfSlot > network diameter
        if self.frameOfSlot > self.diameter:
            for node in self.G:
                if not self.G[node]['rts']:
                    self.G[node]['radio'] = 'off'

        if self.owner: 
            #update state of other nodes:
            #  - if they did a TX last round, and last round was a setup
            #    packet, but they're not forwarders, they should turn 'off'
            if self.packet[0] == 'setup':
                for n in self.G:
                    rs = self.G.node[n]['radioState']
                    if rs == 'tx':
                        rt = self.G.node[n]['rt']
                        if not rt.isBetween(self.slotNum, 0):
                            self.G.node[n]['radioState'] = 'off'
                            #TODO: log UBF: not between
                        else:
                            self.G.node[n]['radioState'] = 'idle'
                            #TODO: log UBF: is between
                            pass

            #  - TTL expired? all idle
            if self.clearTime == 0:
                for n in self.G:
                    self.G.node[n]['radioState'] = 'idle'
            #  - RX last round? tx this round.
            else:
                for n in self.G:
                    if self.G.node[n]['radioState'] == 'rx':
                        self.G.node[n]['radioState'] = 'tx'
    
            #Determine whether we're initiating a new tx, sending
            #  data, etc
            if self.owner['routingState']:
                #setup: 
                #  set packet to ('setup', sn, distance)
                #  set clearTime to network diameter
                #  mark owner as transmitting
                if self.owner['routingState'] == 'setup':
                    self.packet = ('setup', 
                      self.owner['sn'], 
                      self.owner['distance'])
                    self.hopCount = 0
                    self.owner['sn'] += 1
                    self.owner['radio'] = 'tx'
                    self.clearTime = self.diameter
                
                #if last packet has cleared...
                if self.clearTime == 0:
                    #setup? go to ready.
                    if self.owner['routingState'] == 'setup':
                        self.owner['routingState'] = 'ready'

                    #ready? 
                    if self.owner['routingState'] == 'ready':
                        enoughTimeLeft = (self.owner['distance'] 
                          < (self.framesPerSlot - self.frameOfSlot))
                        #go to sending if there's enough time left
                        if enoughTimeLeft:
                            self.packet = (self.owner['queue'].pop(0),
                                self.owner['sn'], None)
                            self.owner['sn'] += 1
                            self.owner['radio'] = 'tx'
                            self.hopCount = 0
                            self.clearTime = self.owner['distance']

            #OK, simulate a round of transmissions
            self.simRound()

            #update routing tables
            #Setup receptions
            if self.packet[0] == 'setup':
                for node in self.G:
                    n = self.G.node[node] 
                    if n['radioState'] == 'rx':
                        n['rt'].addEntry(self.slotNum, 0,
                          self.packet[-1])

            #other receptions
            for node in self.G:
                n = self.G.node[node]
                if n['radioState'] == 'rx':
                    n['rt'].addEntry(self.slotNum, node,
                      self.hopCount)
                    if self.destination == 0xffff or self.destination == node:
                        #TODO: log RX
                        pass

            #decrement clear time
            if self.clearTime:
                self.clearTime -= 1
        else:
            #ok, this is an idle frame so we're cool
            pass
        for node in self.G:
            n = self.G.node[node]
            rs = n['radioState']
            if rs == 'rx':
                n['rxCount'] += 1
            if rs == 'tx':
                n['txCount'] += 1
            if rs == 'idle':
                n['idleCount'] += 1
            if rs == 'off':
                n['offCount'] += 1

    def updateQueues(self):
        #update queue len for any node with nextPacket in the past
        for node in self.G:
            if node != 0 and self.G[node]['nextPacket'] < self.simTime:
                self.G[node]['queue'].append('data')
                self.G[node]['nextPacket'] += (random.random() * self.ipi) + self.ipi /2

    def simFloodBatch(self, senders, simRuns):
        '''Run multiple simulation instances with same set of edges'''
        self.loadEdges()
        for src in senders:
            for i in range(simRuns):
                self.simFlood(src, i)

    def loadEdges(self):
        '''Use previously-set edge provider to regenerate edges'''
        self.G.remove_edges_from(self.G.edges())
        self.G.add_edges_from(self.topo.getEdges())

    def simFlood(self, src = 0, sn=0):
        '''Simulate the effect of one flood'''
        self.simInit(src, sn)
        for d in range(1, self.maxDepth+1):
            self.simRound(d)
        for n in self.G.nodes():
            rr = self.G.node[n]['receiveRound']
            if rr != sys.maxint:
                self.G.node[n]['simResults'].append((src, sn, rr))

#    def simRound(self):
#        '''Simulate one round of communication events'''

    def simInit(self, src, sn):
        '''Initialize node state for a single data transmission'''
        for n in self.G.nodes():
            self.G.node[n]['receiveRound'] = sys.maxint
            if 'simResults' not in self.G.node[n]:
                self.G.node[n]['simResults'] = []
        self.G.node[src]['receiveRound'] = 0

    def depthOutput(self, outFile):
        outFile.write("dest,depth\n")
        for n in self.G.nodes():
            for (src, sn, rr) in self.G.node[n]['simResults']:
                outFile.write('%d,%d\n'%(n, rr))
        outFile.close()

    def textOutput(self, outFile):
        outFile.write("src dest sn depth\n")
        for n in self.G.nodes():
            for (src, sn, rr) in self.G.node[n]['simResults']:
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

    def simRound(self):
        self.hopCount += 1
        receivers = {}
        for n in self.G.nodes():
            #accumulate receptions at each node with incoming packets
            if self.G.node[n]['radioState'] == 'tx':
                for dest in self.G[n]:
                    if self.G.node[dest]['radioState'] == 'idle':
                        prr = self.G[n][dest]['prr']
                        rssi = self.G[n][dest]['rssi']
                        receivers[dest] = receivers.get(dest, []) + [(prr, rssi)]
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
                self.G.node[n]['radioState'] = 'rx'


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
