#!/usr/bin/env python
import sys
import time

from lpp import LppMoteIF

from autoPush.listeners import RecordListener
from autoPush.listeners import PrintfListener
from autoPush.messages import PrintfMsg
from autoPush.messages import LogRecordDataMsg
from autoPush.messages import CxRecordRequestMsg

from autoPush.db import Database

class Dispatcher(object):
    def __init__(self, motestring):
        #hook up to mote
        self.mif = LppMoteIF.LppMoteIF()
        self.tos_source = self.mif.addSource(motestring)
        #format printf's correctly
        self.mif.addListener(PrintfListener.PrintfListener(), 
          PrintfMsg.PrintfMsg)
        self.mif.addListener(RecordListener.RecordListener(), 
          LogRecordDataMsg.LogRecordDataMsg)
        #ugh: not guaranteed that the serial connection is fully
        # opened by this point
        time.sleep(1)

    def stop(self):
        self.mif.finishAll()

    def send(self, m, dest=0):
        self.mif.send(dest, m)

def download(packetSource, bsId, wakeupLen, nodeList):
    print packetSource
    d = Dispatcher(packetSource)
    db = Database.Database()

    try:
        #phase 1: wakeup
        d.mif.wakeup(bsId, wakeupLen)

        #phase 2: clear outstanding buffers
        for node in nodeList:
            rxc = 0
            response = True
            while response:
                d.mif.wakeup(bsId)
                response = d.mif.readFrom(node)
                if not response:
                    print "No response from %u"%(node,)
                else:
                    rxc += 1
                    print "RX %u from %u"%(rxc, node)
            print "Done with ", node
        
        #phase 3: recovery
        request_list = db.findMissing()
        MAX_PACKET_PAYLOAD = 100
        #for request in request_list:
        if request_list:
            for request in request_list:
                request = request_list[0]
    
                msg = CxRecordRequestMsg.CxRecordRequestMsg()
                msg.set_node_id(request['node_id'])
                msg.set_cookie(request['nextCookie'])
                
                if request['missing'] < MAX_PACKET_PAYLOAD:
                    msg.set_length(request['missing'])
                else:
                    msg.set_length(MAX_PACKET_PAYLOAD)
                print "requesting %u at %u from %u"%(msg.get_length(),
                  msg.get_cookie(), msg.get_node_id())
                
                d.send(msg, msg.get_node_id())
                d.mif.readFrom(request['node_id'])
                #keep-alive
                d.mif.wakeup(bsId)
        else:
            print "No repairs needed"
        #done: back to sleep.
        d.mif.sleep(bsId)

    #these two exceptions should just make us clean up/quit
    except KeyboardInterrupt:
        pass
    except EOFError:
        pass
    finally:
        print "Cleaning up"
        d.stop()

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print "Usage:", sys.argv[0], "packetSource(e.g. serial@/dev/ttyUSB0:115200) bsId wakeupLen" 
        sys.exit()

    packetSource = sys.argv[1]
    bsId = int(sys.argv[2])
    wakeupLen = int(sys.argv[3])
    download(packetSource, bsId, wakeupLen, [1])
