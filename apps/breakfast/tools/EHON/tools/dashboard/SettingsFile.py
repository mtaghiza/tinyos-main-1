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


import csv


class SettingsFile(object):

    def __init__(self, fileName):
        self.fileName = fileName

    
    def read(self):
        output = {}
        #try:
        with open(self.fileName, 'rb') as csvfile:
            header = csvfile.next()
            #print header
            #reader = csv.reader(csvfile, delimiter=' ', skipinitialspace=True)   
            for line in csvfile:
                row = line.split()
                if len(row) == 2:
                    output[row[0].strip()] = int(row[1])
        #except:
        #    pass
        return output

    def write(self, settings):
        #try:        
            with open(self.fileName, 'wb') as csvfile:
                csvfile.write("# barcode\tsampling_interval\n")
                writer = csv.writer(csvfile, delimiter='\t')
                
                for node in sorted(settings.iterkeys()):
                    writer.writerow([node, settings[node]])
        #except:
        #    print "error writing settings"
    
    
if __name__ == '__main__':
    fn = SettingsFile("network.settings")
    
    settings = fn.read()

    for node in settings:
        print node, settings[node]
    
    #settings['0400000000000006'] = 66
    #settings['0400000000000007'] = 67
    #settings['0400000000000008'] = 68
    #settings['0400000000000009'] = 69

    print settings

    fn.write(settings)
