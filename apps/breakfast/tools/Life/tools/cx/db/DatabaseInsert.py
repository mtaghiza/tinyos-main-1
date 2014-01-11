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
import time
import threading

import Queue


#OK, so this needs to be running in its own thread.
# - when it starts, connect, create a query queue, 
#   results queue, and results CV. Start the processing loop.
# - execute: insert ('query', query, param, False) tuple into queue
# - executeNow: 
#    - insert ('query', query, param, True) into queue
#    - acquire CV and wait on it.
#    - pop from results queue and return it
#    - exit CV context after popping.
# - processing loop 
#   - read from queue (with timeout)
#   - 'query'
#     - execute query, param.
#     - if the last param is True
#       - do a fetchall 
#       - put the results into the results queue.
#       - acquire CV and notify one
class DatabaseInsert(object):
    TIMEOUT = 60
    COMMIT_TIMEOUT = 2
    TYPE_EXECUTE = 0
    TYPE_EXECUTE_NOW = 1
    TYPE_STOP = 2
    TYPE_STOP_SYNCH = 3

    def __init__(self, dbName):
        self.dbName = dbName
        self.connected = False
        self.taskQueue = Queue.Queue()
        self.resultsQueue = Queue.Queue()
        self.resultsCV = threading.Condition()
        self.stopSynchCV = threading.Condition()


    def mainLoop(self):
        try:
            self.connect()
            self.active = True
            lastAction = time.time()
            lastCommit = time.time()
            while self.active and (time.time() - lastAction) < DatabaseInsert.TIMEOUT :
                try:
                    taskTuple = self.taskQueue.get(True, 0.25)
                    (t, q, p) = taskTuple
                    if t == DatabaseInsert.TYPE_EXECUTE:
                        self.connection.execute(q,p)
                    elif t == DatabaseInsert.TYPE_EXECUTE_NOW:
                        print "exec now", q, p
                        self.connection.commit()
                        with self.resultsCV:
                            self.resultsQueue.put(self.connection.execute(q,p).fetchall())
                            self.resultsCV.notify()
                    elif t == DatabaseInsert.TYPE_STOP:
                        print "Async stop"
                        self.active = False
                    elif t == DatabaseInsert.TYPE_STOP_SYNCH:
                        print "synchronous stop"
                        with self.stopSynchCV:
                            self.active = False
                            self.closeConnection()
                            self.stopSynchCV.notify_all()
                    lastAction = time.time()
                    if time.time() - lastCommit > DatabaseInsert.COMMIT_TIMEOUT:
                        if self.connected:
                            print "%.f elapsed, commit"%(DatabaseInsert.COMMIT_TIMEOUT,)
                            self.connection.commit()
                            lastCommit = time.time()
                except Queue.Empty:
                    pass
        except:
            raise
        finally:
            self.closeConnection()


    def connect(self):
        if not self.connected:
            self.connected = True
            self.connection = sqlite3.connect(self.dbName)

    def stop(self):
        with self.stopSynchCV:
            print "waiting for db stop"
            self.taskQueue.put((DatabaseInsert.TYPE_STOP_SYNCH, None, None))
            self.stopSynchCV.wait()
        print "db stopped"


    def closeConnection(self):
        print "explicit close"
        if self.connected:
            self.connection.commit()
            self.connection.close()
            self.connected = False
                
    def __del__(self):
        print "delete insert object, signal stop"
        self.taskQueue.put((DatabaseInsert.TYPE_STOP,None, None))
        
    def insertFlash(self, node_id, cookie, nextCookie, length):
        cookieDiff = nextCookie - (cookie + length)
        if (0 < length) and (length < 140) and (cookieDiff > 0) and (cookieDiff < 0xFF):
            # the table has a PK uniqueness constraint on (node_id, cookie)
            # duplicate data is ignored
            row = [node_id, time.time(), cookie, nextCookie, length]
            self.execute('INSERT OR IGNORE INTO cookie_table (node_id, base_time, cookie, nextCookie, length) VALUES (?,?,?,?,?)', row)        

    def insertRaw(self, source, message):
        self.execute('INSERT INTO packet (src, ts, amId, data) values (?, ?, ?, ?)',
            (message.addr, 
              time.time(), 
              message.am_type,
              sqlite3.Binary(bytearray(message.data))))

    def execute(self, query, args):
        self.taskQueue.put( (DatabaseInsert.TYPE_EXECUTE, query, args))

    def executeNow(self, query, args):
        with self.resultsCV:
            self.taskQueue.put( (DatabaseInsert.TYPE_EXECUTE_NOW, query, args))
            self.resultsCV.wait()
            return self.resultsQueue.get()
