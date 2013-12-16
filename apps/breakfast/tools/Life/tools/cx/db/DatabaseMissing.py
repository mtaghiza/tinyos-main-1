#!/usr/bin/env python

import sqlite3
import threading
import sys

class DatabaseMissing(object):

    SORT_COOKIE_SQL = '''CREATE TEMPORARY TABLE sorted_flash 
                        AS SELECT * 
                        FROM cookie_table 
                        ORDER BY node_id, cookie;'''
                            
    MISSING_ORDER_AGE_SQL = '''SELECT l.node_id, 
      l.cookie, l.nextCookie,
      (r.cookie - l.nextCookie -1) as missing,
      l.retry
    FROM sorted_flash l
    JOIN sorted_flash r
    ON l.node_id = r.node_id
      AND l.ROWID +1 = r.ROWID
      AND missing > 6
      AND l.retry < 5
      ORDER BY l.node_id, l.cookie'''

    TOTAL_MISSING_BY_NODE= '''SELECT 
        sum(r.cookie - l.nextCookie -1) as totalMissing
      FROM sorted_flash l
      JOIN sorted_flash r
        ON l.node_id=r.node_id and l.ROWID+1=r.ROWID
      WHERE l.node_id=?
        AND r.cookie - l.nextCookie > 6
        AND l.retry < 5
      GROUP BY l.node_id'''


    MISSING_ORDER_SIZE_SQL = '''SELECT l.node_id, 
      l.cookie, l.nextCookie,
      (r.cookie - l.nextCookie -1) as missing,
      l.retry
    FROM sorted_flash l
    JOIN sorted_flash r
    ON l.node_id = r.node_id
      AND l.ROWID +1 = r.ROWID
      AND missing > 6
      AND l.retry < 5
      ORDER BY l.node_id, missing desc'''

    MISSING_ORDER_SIZE_NODE_SQL = '''SELECT l.node_id, 
      l.cookie, l.nextCookie,
      (r.cookie - l.nextCookie -1) as missing,
      l.retry
    FROM sorted_flash l
    JOIN sorted_flash r
    ON l.node_id = r.node_id
      AND l.ROWID +1 = r.ROWID
      AND missing > 6
      AND l.retry < 5
    WHERE l.node_id = ?
    ORDER BY l.node_id, missing desc'''


    def __init__(self, dbName):
        self.dbName = dbName
        self.connected = False

        print "DatabaseMissing()", threading.current_thread().name

                
    def __del__(self):
        if self.connected == True:
            #self.cursor.close()
            self.connection.close()
            print "closing connection"

    def nodeMissing(self, node, incrementRetries=True):
        # sqlite connections can only be used from the same threads they are established from
        if self.connected == False:
            self.connected == True
            # raises sqlite3 exceptions
            self.connection = sqlite3.connect(self.dbName)
            #self.cursor = self.connection.cursor()
        # sort the flash table by cookie values (ascending)
        # and find missing segments by comparing lengths and cookies
        self.connection.execute(DatabaseMissing.SORT_COOKIE_SQL)
        results = self.connection.execute(DatabaseMissing.MISSING_ORDER_SIZE_NODE_SQL, (node,))
        repairInfo = results.fetchone()
        if repairInfo:
            results = self.connection.execute(DatabaseMissing.TOTAL_MISSING_BY_NODE,
              (node,))
            (totalMissing,) = results.fetchone()
            return (repairInfo, totalMissing)
        else:
            return repairInfo
        

    def findMissing(self, incrementRetries=True):
        
        # sqlite connections can only be used from the same threads they are established from
        if self.connected == False:
            self.connected == True
            # raises sqlite3 exceptions
            self.connection = sqlite3.connect(self.dbName)
            #self.cursor = self.connection.cursor()

        # sort the flash table by cookie values (ascending)
        # and find missing segments by comparing lengths and cookies
        self.connection.execute(DatabaseMissing.SORT_COOKIE_SQL)
        results = self.connection.execute(DatabaseMissing.MISSING_ORDER_SIZE_SQL)
        
        #results = self.connection.fetchall()

        last_result = None
        missingMap = {}

        # get first entry for each node_id, increment the retry counter
        # and remove old records from the source table
        allMissing = [res for res in results]
        for res in allMissing:
            if last_result != res[0]:
                
                last_result = res[0]
                
                hash = {'node_id':res[0], 'cookie':res[1], 'nextCookie':res[2], 'missing':res[3], 'retry':res[4]}
                missingMap[res[0]] = hash
                
                if incrementRetries:
                    node_id_field = res[0]
                    cookie_field = res[1]
                    retry_field = res[4] + 1
                    new_values = (retry_field, node_id_field, cookie_field)
                    self.connection.execute('UPDATE cookie_table SET retry=? WHERE node_id=? AND cookie=?', new_values)

                #old_records = (node_id_field, cookie_field)
                #self.cursor.execute('DELETE FROM cookie_table WHERE node_id=? AND cookie<?', old_records)
        
        self.connection.commit()

        return (missingMap, allMissing)
        
        #row = [node_id, time.time(), cookie, length]
        #self.cursor.execute('INSERT INTO cookie_table (node_id, base_time, cookie, length) VALUES (?,?,?,?)', row)        
        #self.connection.commit();


if __name__ == '__main__':
    dbName = 'database0.sqlite'
    if len(sys.argv) > 1:
        dbName = sys.argv[1]
    dbm = DatabaseMissing(dbName)
    if len(sys.argv) <= 2:
        (toReq, allMissing) = dbm.findMissing(False)
        for m in allMissing:
            print "GAP", m
        for m in toReq:
            print "REQ",m
    else:
        print dbm.nodeMissing(int(sys.argv[2]), False)
