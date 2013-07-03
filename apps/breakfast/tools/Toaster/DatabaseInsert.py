#!/usr/bin/env python

import sqlite3
import time
import threading

class DatabaseInsert(object):

    def __init__(self, dbName):
        self.dbName = dbName
        self.connected = False
        #print "DatabaseInsert()", threading.current_thread().name

                
    def __del__(self):
        if self.connected == True:
            self.cursor.close()
            self.connection.close()
            
            print "closing connection"

    def insertBacon(self, bacon):
        # sqlite connections can only be used from the same threads they are established from
        if self.connected == False:
            self.connected == True
            # raises sqlite3 exceptions
            self.connection = sqlite3.connect(self.dbName)
            self.connection.text_factory = sqlite3.OptimizedUnicode
            self.cursor = self.connection.cursor()

        self.cursor.execute('''INSERT OR IGNORE INTO bacon_table 
                                    (bacon_id, time, manufacture_id, gain, offset,
                                    c15t30, c15t85, c20t30, c20t85, c25t30, c25t85,
                                    c15vref, c20vref, c25vref) VALUES 
                                    (?,?,?,?,?,?,?,?,?,?,?,?,?,?)''', bacon)            
        self.connection.commit();

    def insertToast(self, toast):
        # sqlite connections can only be used from the same threads they are established from
        if self.connected == False:
            self.connected == True
            # raises sqlite3 exceptions
            self.connection = sqlite3.connect(self.dbName)
            self.connection.text_factory = sqlite3.OptimizedUnicode
            self.cursor = self.connection.cursor()

        self.cursor.execute('''INSERT OR IGNORE INTO toast_table 
                                    (toast_id, time, gain, offset,
                                    c15t30, c15t85, c25t30, c25t85,
                                    c15vref, c25vref) VALUES 
                                    (?,?,?,?,?,?,?,?,?,?)''', toast)            
        self.connection.commit();

    def insertSensors(self, sensors):
        # sqlite connections can only be used from the same threads they are established from
        if self.connected == False:
            self.connected == True
            # raises sqlite3 exceptions
            self.connection = sqlite3.connect(self.dbName)
            self.connection.text_factory = sqlite3.OptimizedUnicode
            self.cursor = self.connection.cursor()
            
        toast_id = sensors[0]
        time = sensors[1]
        assignments = sensors[2]
        
        for channel in range(0,8):
            if assignments[0][channel] and assignments[1][channel]:
                sensor = [assignments[0][channel], assignments[1][channel]]
                
                self.cursor.execute('''SELECT sensor_id, type, max(time), toast_id, channel 
                                        FROM sensor_table WHERE sensor_id = ? and type = ?''', sensor)
                row = self.cursor.fetchone()
                
                if not (row[3] == toast_id and row[4] == channel):
                    print "insert", row
                        
                    assign = [assignments[0][channel], assignments[1][channel], time, toast_id, channel]
                    self.cursor.execute('''INSERT OR IGNORE INTO sensor_table 
                                        (sensor_id, type, time, toast_id, channel) 
                                        VALUES (?,?,?,?,?)''', assign)            
                    self.connection.commit();
                else:
                    print "skip", row, toast_id, channel
    
