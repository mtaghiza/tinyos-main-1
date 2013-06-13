#!/usr/bin/env python

import sqlite3
import csv


class DatabaseExport(object):

    def __init__(self, dbName):
        self.dbName = dbName
        self.connected = False

    def __del__(self):
        if self.connected == True:
            self.cursor.close()
            self.connection.close()
            
            print "closing connection"

    def exportCookie(self):

        # sqlite connections can only be used from the same threads they are established from
        if self.connected == False:
            self.connected == True
            # raises sqlite3 exceptions
            self.connection = sqlite3.connect(self.dbName)
            self.cursor = self.connection.cursor()

        self.cursor.execute("select * from cookie_table order by cookie;")

        csvName = 'cookie.csv'
        
        with open(csvName, 'wb') as csvfile:
            csvWriter = csv.writer(csvfile)
            csvWriter.writerow([i[0] for i in self.cursor.description]) # write headers
            csvWriter.writerows(self.cursor)



if __name__ == '__main__':

    from Database import Database 

    db = Database()

    db.exportCookie()

