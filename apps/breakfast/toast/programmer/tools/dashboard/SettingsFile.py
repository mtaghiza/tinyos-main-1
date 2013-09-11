#!/usr/bin/env python

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