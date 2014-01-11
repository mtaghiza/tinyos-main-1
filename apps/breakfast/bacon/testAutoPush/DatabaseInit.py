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
import sys
import threading


#This class initializes the sqlite database file and creates xxx tables:
#- raw_table
#- meta_table
#- cookie_table
#- time_table
#If the file is not a sqlite db (corruption) a new file will be created.
#If the tables do not exist, they will be created.

#Exceptions thrown by sqlite
#
#StandardError
#|__Warning
#|__Error
#   |__InterfaceError
#   |__DatabaseError
#      |__DataError
#      |__OperationalError
#      |__IntegrityError
#      |__InternalError
#      |__ProgrammingError
#      |__NotSupportedError


class DatabaseInit(object):

    # constants 
    FILE_RETRIES = 10
    NO_OF_TABLES = 4

    # final name for db in use
    dbName = None

    # Table creation strings
    RAW_TABLE_SQL = '''CREATE TABLE raw_table
                       (node_id INTEGER,
                        base_time REAL,
                        sensor_id INTEGER, 
                        node_time INTEGER, 
                        sample_raw INTEGER);'''
                        
    META_TABLE_SQL = '''CREATE TABLE meta_table
                        (node_id INTEGER,
                         base_time REAL,
                         sensor_id INTEGER,
                         node_time INTEGER,
                         toast_id INTEGER,
                         calibrate text);'''
                         
    FLASH_TABLE_SQL = '''CREATE TABLE cookie_table
                         (node_id INTEGER NOT NULL,
                          base_time REAL,
                          cookie INTEGER NOT NULL,
                          nextCookie INTEGER,
                          length INTEGER,
                          retry INTEGER DEFAULT 0,
                          PRIMARY KEY (node_id, cookie));'''

    TIME_TABLE_SQL = '''CREATE TABLE time_table
                        (node_id INTEGER,
                         base_time REAL,
                         node_time INTEGER,
                         neighbor_id INTEGER);'''
                     


    # class finds suitable filename for DB and creates tables if needed
    def __init__(self, rootName):

        # retry multiple filenames by incrementing counter in filename
        # a filename is accepted if either tables exists in it or 
        # tables can be created
        for fileCounter in range(0, DatabaseInit.FILE_RETRIES):
            dbFile = rootName + str(fileCounter) + '.sqlite'

            try:
                connection = sqlite3.connect(dbFile)

                cursor = connection.cursor()
                cursor.execute('''SELECT name FROM sqlite_master WHERE name LIKE '%_table';''')

                if len(cursor.fetchall()) != DatabaseInit.NO_OF_TABLES:
                    sys.stderr.write("Tables do not exist, create tables\n")

                    cursor.execute(DatabaseInit.RAW_TABLE_SQL);
                    cursor.execute(DatabaseInit.META_TABLE_SQL);
                    cursor.execute(DatabaseInit.FLASH_TABLE_SQL);
                    cursor.execute(DatabaseInit.TIME_TABLE_SQL);
                    connection.commit();
 
                # only set name if no exceptions thrown
                self.dbName = dbFile

            except sqlite3.Error:
                sys.stderr.write("Error reading file: " + dbFile + "\n")
                continue
            finally:
                cursor.close()
                connection.close()
            break
            
        if self.dbName is None:
            raise IOError

        print "DatabaseInit()", threading.current_thread().name

    def getName(self):
        return self.dbName

# class test function
if __name__ == '__main__':

    try:
        db = DatabaseInit('database')
        print db.getName()
    except IOError:
        print "caught error"
    
    


