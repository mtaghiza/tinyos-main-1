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
# if True:
#     if True:
        dest = 0xFFFF
        src = tunneledSrc
        length = len(data[4:])
        group = 0xFF
        serialHeader = struct.pack(">HHBBB", 
          dest, src, length, group, am_type);
        packet = serialHeader + data[3:]
#         serial_pkt = SerialPacket(packet[1:],
#                                   data_length=len(packet)-1)
#         print serial_pkt
#         serial_pkt = SerialPacket(packet,
#                                   data_length=len(packet)-1)
#         print serial_pkt
#         serial_pkt = SerialPacket('x'+packet[1:],
#                                   data_length=len(packet)-1)
#         print serial_pkt
        if self.receiveQueue:
            self.receiveQueue.put((None, 'x'+packet))
        else:
            print "Warning: Decoded tunneled-packet record but no receiveQueue to handle packet"
