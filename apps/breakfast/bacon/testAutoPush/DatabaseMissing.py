#!/usr/bin/env python

import sqlite3
import threading

class DatabaseMissing(object):

    SORT_COOKIE_SQL = '''CREATE TEMPORARY TABLE sorted_flash 
                        AS SELECT * 
                        FROM cookie_table 
                        ORDER BY node_id, cookie;'''
                            
    MISSING_ORDER_AGE_SQL = '''SELECT t1.node_id, 
                                t1.cookie, 
                                t1.nextCookie, 
                                (t2.cookie - t1.nextCookie - 1) AS missing, 
                                t1.retry
                            FROM sorted_flash AS t1, sorted_flash AS t2
                            WHERE (t1.node_id = t2.node_id)
                                AND (t1.ROWID = t2.ROWID - 1) 
                                AND (missing > 0) 
                                AND (t1.retry < 5)
                            ORDER BY t1.node_id, t1.cookie;'''


    def __init__(self, dbName):
        self.dbName = dbName
        self.connected = False

        print "DatabaseMissing()", threading.current_thread().name

                
    def __del__(self):
        if self.connected == True:
            #self.cursor.close()
            self.connection.close()
            
            print "closing connection"

    def findMissing(self):
        
        # sqlite connections can only be used from the same threads they are established from
        if self.connected == False:
            self.connected == True
            # raises sqlite3 exceptions
            self.connection = sqlite3.connect(self.dbName)
            #self.cursor = self.connection.cursor()

        # sort the flash table by cookie values (ascending)
        # and find missing segments by comparing lengths and cookies
        self.connection.execute(DatabaseMissing.SORT_COOKIE_SQL)
        results = self.connection.execute(DatabaseMissing.MISSING_ORDER_AGE_SQL)
        
        #results = self.connection.fetchall()

        last_result = None
        missing_list = []


        # get first entry for each node_id, increment the retry counter
        # and remove old records from the source table
        for res in results:
            if last_result != res[0]:
                
                last_result = res[0]
                
                hash = {'node_id':res[0], 'cookie':res[1], 'nextCookie':res[2], 'missing':res[3], 'retry':res[4]}
                missing_list.append(hash)
                
                node_id_field = res[0]
                cookie_field = res[1]
                retry_field = res[4] + 1
                
                new_values = (retry_field, node_id_field, cookie_field)
                
                self.connection.execute('UPDATE cookie_table SET retry=? WHERE node_id=? AND cookie=?', new_values)

                #old_records = (node_id_field, cookie_field)
                #self.cursor.execute('DELETE FROM cookie_table WHERE node_id=? AND cookie<?', old_records)
        
        self.connection.commit();

        return missing_list
        
        #row = [node_id, time.time(), cookie, length]
        #self.cursor.execute('INSERT INTO cookie_table (node_id, base_time, cookie, length) VALUES (?,?,?,?)', row)        
        #self.connection.commit();







