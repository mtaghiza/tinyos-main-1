#!/usr/bin/env python

import struct
from autoPush.decoders import Decoder
from tinyos.message.Message import Message

from tinyos.message.SerialPacket import SerialPacket

class Tunneled(Decoder.Decoder):
    def __init__(self, *args):
        Decoder.Decoder.__init__(self, *args)
        self.receiveQueue = None
        
    @classmethod 
    def recordType(cls):
        return 0x15

    def insert(self, source, cookie, data):
        data = ''.join(chr(v) for v in data)
        (tunneledSrc, am_type) = struct.unpack('>HB', data[0:3])

        #and here's a fake serial header
        dest = 0xFFFF
        src = tunneledSrc
        length = len(data[3:])
        group = 0xFF
        #the leading 0 is because apparently MoteIf.dispatchPacket
        # throws away the first byte 
        serialHeader = struct.pack(">BHHBBB", 
          0,
          dest, src, length, group, am_type);
        packet = serialHeader + data[3:]
        if self.receiveQueue:
            self.receiveQueue.put((None, packet))
        else:
            print "Warning: Decoded tunneled-packet record but no receiveQueue to handle packet"
