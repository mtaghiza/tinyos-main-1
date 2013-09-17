#!/usr/bin/env python
from tools.cx.decoders import Decoder

class LogPrintf(Decoder.Decoder):
    @classmethod
    def recordType(cls):
        return 0x18

    def insert(self, source, cookie, data):
        print "#LOGPRINTF %u %s"%(source, 
          ''.join([chr(v) for v in data]))
