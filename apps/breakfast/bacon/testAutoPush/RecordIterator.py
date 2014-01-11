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


class RecordIterator(object):
    COOKIE_LEN = 4
    LENGTH_LEN = 1
    
    def val(self, arr):
        return reduce(lambda l, r: (l<<8) + r, arr, 0)

    def __init__(self, recordMsg):
        self.data = recordMsg.get_data()
        self.si = 0

    def __iter__(self):
        return self

    def next(self):
        while self.si < len(self.data):
            cookieBytes = self.data[self.si:self.si+RecordIterator.COOKIE_LEN]
            self.si += RecordIterator.COOKIE_LEN
            if cookieBytes == [0xff, 0xff, 0xff, 0xff]:
                raise StopIteration
            cookieVal = self.val(cookieBytes)
            lenVal = self.val(self.data[self.si:self.si+RecordIterator.LENGTH_LEN])
            self.si += RecordIterator.LENGTH_LEN
            recordData = self.data[self.si:self.si + lenVal]
            self.si += lenVal
            return (cookieVal, lenVal, recordData)
        raise StopIteration


