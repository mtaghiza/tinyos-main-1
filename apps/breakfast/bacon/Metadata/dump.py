#!/usr/bin/env python

import sys, time, thread

from tinyos.message import *
from tinyos.message.Message import *
from tinyos.message.SerialPacket import *
from tinyos.packet.Serial import Serial
#import tos
 
import PrintfMsg


class DataLogger:
    def __init__(self, motestring):
        self.mif = MoteIF.MoteIF()
        self.tos_source = self.mif.addSource(motestring)
        self.mif.addListener(self, PrintfPacket.PrintfPacket)
    
    def receive(self, src, msg):
        print msg
        pass

#     def seek(self, dest, seekTo):
#         smsg = SeekPacket.SeekPacket()
#         smsg.set_cookie(seekTo)
#         self.mif.sendMsg(self.tos_source, 
#           dest,
#           smsg.get_amType(), 0, smsg)
 
if __name__ == '__main__':
    packetSource = 'sf:localhost:9002'

    if len(sys.argv) < 1:
        print "Usage:", sys.argv[0], "[packetSource=sf:localhost:9002]" 
        sys.exit()

    if len(sys.argv) > 1:
        packetSource = sys.argv[1]

    try:
        dl = DataLogger(packetSource)
        while True:
            pass

    except KeyboardInterrupt:
        pass

