#!/usr/bin/env python

import sys
import time

class PrintfListener(object):
    def __init__(self, bsId):
        self.buf=''
        self.bsId = bsId
        pass
    
    def receive(self, src, msg):
        mb = msg.get_buffer()
        if 0 in mb:
            mb = mb[:mb.index(0)]
        self.buf += ''.join(chr(v) for v in mb)
        self.buf.replace('\r', '')
        while '\n' in self.buf:
            r = self.buf.split('\n', 1)
            line = r[0]
            if len(r):
                self.buf=r[1]
            else:
                self.buf = ''
            if line:
                sys.stdout.write("#PRINTF %.2f %u %s\n"%(time.time(), self.bsId, line ))
