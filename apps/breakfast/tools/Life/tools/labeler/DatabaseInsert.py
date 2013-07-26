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

    def attachSensors(self, sensors):
        # sqlite connections can only be used from the same threads they are established from
        if self.connected == False:
            self.connected == True
            # raises sqlite3 exceptions
            self.connection = sqlite3.connect(self.dbName)
            self.connection.text_factory = sqlite3.OptimizedUnicode
            self.cursor = self.connection.cursor()
            
        toast_id = sensors[0]
        assignments = sensors[1]
        
        for channel in range(0,8):
            # non-zero and non-None entries in the assignment array
            # are new sensor assignments
            if assignments[0][channel] and assignments[1][channel]:
                sensor_id = assignments[0][channel]
                type = assignments[1][channel]
                
                # find open entries in the sensor table for (sensor_id, type)-tuple
                self.cursor.execute('''SELECT sensor_id, type, max(time), toast_id, channel 
                                        FROM sensor_table WHERE sensor_id = ? AND type = ? AND detached IS NULL''', [sensor_id, type])
                row = self.cursor.fetchone()
                
                if row is not None:
                    # if entry is exact match (duplicate), ignore and skip to next
                    if row[3] == toast_id and row[4] == channel:
                        print "skip", row, toast_id, channel
                        continue
                    
                    # sensor exists in table, close previous record
                    # note: row is not None if an open entry exists given query above 
                    self.cursor.execute('''UPDATE OR IGNORE sensor_table
                                        SET detached = ? 
                                        WHERE sensor_id = ? AND type = ? AND detached IS NULL''', [time.time(), row[0], row[1]])
                    self.connection.commit()
                    
                    
                # see if there is already a sensor attached to the (toast_id, channel)-tuple
                # and close that entry before inserting a new (sensor_id, type, toast_id, channel)-tuple
                self.cursor.execute('''SELECT sensor_id, type, time, toast_id, channel 
                                        FROM sensor_table WHERE toast_id = ? AND channel = ? AND detached IS NULL''', [toast_id, channel])
                row = self.cursor.fetchone()
                if row is not None:
                    self.cursor.execute('''UPDATE OR IGNORE sensor_table
                                        SET detached = ? 
                                        WHERE sensor_id = ? AND type = ? AND detached IS NULL''', [time.time(), row[0], row[1]])
                    self.connection.commit()
                
                
                # insert new record in sensor table
                self.cursor.execute('''INSERT OR IGNORE INTO sensor_table 
                                    (sensor_id, type, time, detached, toast_id, channel) 
                                    VALUES (?,?,?,NULL,?,?)''', [sensor_id, type, time.time(), toast_id, channel])            
                self.connection.commit()
                
            # special case: both sensor_id and type are zero which means this channel should be reset
            elif assignments[0][channel] == 0 and assignments[1][channel] == 0:
                # close entry for current toast_id and channel
                self.cursor.execute('''UPDATE OR IGNORE sensor_table
                                    SET detached = ? 
                                    WHERE toast_id = ? AND channel = ? AND detached IS NULL''', [time.time(), toast_id, channel])
                self.connection.commit()


    def detachSensors(self, toast):
        # sqlite connections can only be used from the same threads they are established from
        if self.connected == False:
            self.connected == True
            # raises sqlite3 exceptions
            self.connection = sqlite3.connect(self.dbName)
            self.connection.text_factory = sqlite3.OptimizedUnicode
            self.cursor = self.connection.cursor()
        
            self.cursor.execute('''UPDATE OR IGNORE sensor_table
                                SET detached = ? 
                                WHERE toast_id = ? AND detached IS NULL''', [time.time(), toast])
            self.connection.commit()        
    
    
    
