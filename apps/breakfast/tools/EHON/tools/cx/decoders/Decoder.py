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

def toHexArrayStr(data):
   return "[" + ', '.join([hex(v) for v in data])+ "]" 

def toHexStr(dataBin, reverseByteOrder = True):
    if reverseByteOrder:
        arr = reversed(dataBin)
    else:
        arr = dataBin
    return '0x'+''.join(['%02x'%ord(c) for c in arr])
        

def tlvIterator(data):
    #skip CRC
    i = 2
    while i < len(data):
        #format:
        # tag, len, [b x len]
        tag = ord(data[i])
        l = ord(data[i+1])
        d = data[i+2:i+2+l]
        yield (tag, l, d)
        i += l+2

class Decoder(object):
    def __init__(self, dbInsert):
        self.dbInsert = dbInsert

    def __del__(self):
        pass

    @classmethod
    def decode(self, arr, reverseByteOrder=True):
        if reverseByteOrder:
            return reduce(lambda l, r: (l<<8) + r, reversed(arr), 0)
        else:
            return reduce(lambda l, r: (l<<8) + r, arr, 0)

    @classmethod
    def recordType(cls):
        return None

    def insert(self, source, cookie, data):
        pass
