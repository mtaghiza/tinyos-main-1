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


import sqlite3
import threading
import sys

class DatabaseMissing(object):

##TODO: this query uses the end of the log (as reported by status
## messages) in the gap computation. It works correctly, but only if
## the find-missing command is run when the database is all synched up,
## not if it gets run from a separate thread.
#     SORT_COOKIE_SQL = '''CREATE TEMPORARY TABLE sorted_flash 
#                         AS SELECT node_id, cookie, nextCookie, retry
#                         FROM cookie_table 
#                         UNION SELECT node1 as node_id, 
#                           writeCookie as cookie,
#                           writeCookie + 1 as nextCookie,
#                           0 as retry
#                           FROM base_reference
#                         ORDER BY node_id, cookie;'''
    SORT_COOKIE_SQL = '''CREATE TEMPORARY TABLE sorted_flash 
                        AS SELECT node_id, cookie, nextCookie, retry
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
    
    #TODO: add function that performs the same query as node missing,
    # but restricts it to a range of cookie values.
    # This could probably be accomplished most easily by adding
    # parameters to SORT_COOKIE_SQL that limit what goes into that
    # temp table.

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

    def allNodeMissing(self, node, incrementRetries=True):
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
        repairInfo = results.fetchall()
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
