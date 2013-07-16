#!/usr/bin/env python

import sqlite3
import csv
import datetime

class DatabaseExport(object):

    def __init__(self, dbName):
        self.dbName = dbName
        self.connected = False

    def __del__(self):
        if self.connected == True:
            self.cursor.close()
            self.connection.close()
            
            print "closing connection"

    def exportCSV(self):

        # sqlite connections can only be used from the same threads they are established from
        if self.connected == False:
            self.connected == True
            # raises sqlite3 exceptions
            self.connection = sqlite3.connect(self.dbName)
            self.cursor = self.connection.cursor()

        now = datetime.datetime.now()
        nowStr = now.strftime("%Y%m%dT%H%M%S")
        
        baconStr = 'bacon.' + nowStr + '.csv'
        toastStr = 'toast.' + nowStr + '.csv'
        sensorsStr = 'sensors.' + nowStr + '.csv'
        
        tableStr = ['bacon_table', 'toast_table', 'sensor_table']
        nameStr = [baconStr, toastStr, sensorsStr]
        
        for j in range(0,3):

            self.cursor.execute("select * from %s order by time;" % tableStr[j])

            with open(nameStr[j], 'wb') as csvfile:
                csvWriter = csv.writer(csvfile)
                csvWriter.writerow([i[0] for i in self.cursor.description]) # write headers
                csvWriter.writerows(self.cursor)



if __name__ == '__main__':

    from Database import Database 

    db = Database()

    db.exportCookie()

