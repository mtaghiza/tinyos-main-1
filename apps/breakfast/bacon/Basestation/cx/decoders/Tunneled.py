#!/usr/bin/env python

from autoPush.decoders import Decoder
from tinyos.message.Message import Message

class Tunneled(Decoder.Decoder):
    def __init__(self, *args):
        Decoder.Decoder.__init__(self, *args)
        self.receiveQueue = None
        
    @classmethod 
    def recordType(cls):
        return 0x15

    def insert(self, source, cookie, data):
        tunneledSrc = self.decode(data[0:2])
        am_type = self.decode(data[2:4])
        tunneledData = data[4:]
        if self.receiveQueue:
            m = Message(tunneledData, tunneledSrc)
            m.am_type = am_type
            self.receiveQueue.put(m)
        else:
            print "Warning: Decoded tunneled-packet record but no receiveQueue to handle packet"
