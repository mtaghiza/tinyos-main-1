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


import struct
from tools.cx.decoders import Decoder
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
