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

    def unpack(self, source, cookie, data):
        rc = self.decode(data[0:2])
        baseTime = self.decode(data[2:6])
        battery = self.decode(data[6:8])
        light = self.decode(data[8:10])
        thermistor = self.decode(data[10:12])
        return (source, cookie, rc, baseTime, battery, light, thermistor)

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
