import sqlite3

import tools.cx.constants as constants
import time

class ExtractRaw(object):

    def __init__(self, in_dbName, out_dbName):
        self.in_dbName = in_dbName
        self.out_dbName = out_dbName
        self.connected = False
        print "EXR %s %s"%(in_dbName) %(out_dbName)


    def __del__(self):
        if self.connected == True:
            self.cursor.close()
            self.connection.close()

            print "closing connection"

    def getBinary():


    def getBinaryById():


    def
