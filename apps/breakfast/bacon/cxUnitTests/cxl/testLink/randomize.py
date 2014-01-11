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

import sys
import sqlite3
import random

if __name__ == '__main__':
    if len(sys.argv) < 6:
        print >> sys.stderr, "Usage: python %s db (cx|sp) src dest failRate"%(sys.argv[0],)
        sys.exit(1)
    db = sys.argv[1]
    setup = sys.argv[2]
    src=int(sys.argv[3])
    dest=int(sys.argv[4])
    fr=float(sys.argv[5])
    c = sqlite3.connect(db)
    q=''
    if setup == 'cx':
        q = 'SELECT f FROM CXFS where src=? and dest=? and bw=2'
    elif setup=='sp':
        q = 'SELECT f FROM sp_thresh_entry where src=? and dest=? and prr=0.99'
    elif setup=='spe':
        q = 'SELECT f FROM sp_etx_entry where src=? and dest=?'
        

    for (f,) in c.execute(q, (src, dest)).fetchall():
        if f == src or f==dest or random.random() > fr:
            print "%d r"%(f,)
        else:
            print "%d q"%(f,)
