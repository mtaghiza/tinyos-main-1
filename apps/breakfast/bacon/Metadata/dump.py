#!/usr/bin/env python

import sys, time, thread

from tinyos.message import *
from tinyos.message.Message import *
from tinyos.message.SerialPacket import *
from tinyos.packet.Serial import Serial
#import tos
from mig import PrintfMsg

class PrintfLogger:
    def __init__(self):
        self.buf=''
        pass
    
    def receive(self, src, msg):
        mb = msg.get_buffer()
        if 0 in mb:
            mb = mb[:mb.index(0)]
        sys.stdout.write(''.join(chr(v) for v in mb))


class Dispatcher:
    def __init__(self, motestring):
        self.mif = MoteIF.MoteIF()
        self.tos_source = self.mif.addSource(motestring)
        self.mif.addListener(PrintfLogger(), PrintfMsg.PrintfMsg)

    def stop(self):
        self.mif.finishAll()
    
#     def seek(self, dest, seekTo):
#         smsg = SeekPacket.SeekPacket()
#         smsg.set_cookie(seekTo)
#         self.mif.sendMsg(self.tos_source, 
#           dest,
#           smsg.get_amType(), 0, smsg)

if __name__ == '__main__':
    #TODO: unclear why serial@/dev/ttyUSBx:115200 doesn't work.
    #Seems like the python serial libraries from TOS don't support raw
    # serial access: would need something that implements PacketSource
    # methods and just uses the python serial libs to read/write
    # directly.
    packetSource = 'sf@localhost:9002'

    if len(sys.argv) < 1:
        print "Usage:", sys.argv[0], "[packetSource=sf@localhost:9002]" 
        sys.exit()

    if len(sys.argv) > 1:
        packetSource = sys.argv[1]

    try:
        d = Dispatcher(packetSource)
        while True:
            pass

    except KeyboardInterrupt:
        d.stop()
        pass

