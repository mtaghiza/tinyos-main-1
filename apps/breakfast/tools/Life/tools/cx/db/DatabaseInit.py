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


import sys
import threading
import subprocess
import datetime
import os
import pyodbc
from ...config import db_name, connection_string

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
    tables = {'cookie_table': '''CREATE TABLE cookie_table
                         (node_id INTEGER NOT NULL,
                          base_time REAL,
                          cookie INTEGER NOT NULL,
                          nextCookie INTEGER,
                          length INTEGER,
                          retry INTEGER DEFAULT 0,
                          PRIMARY KEY (node_id, cookie))''',
              'log_record': '''CREATE TABLE log_record
                        (node_id INTEGER,
                         cookie INTEGER,
                         data BLOB,
                         PRIMARY KEY (node_id, cookie))''',
              'bacon_sample': '''CREATE TABLE bacon_sample
                        (node_id INTEGER,
                         cookie INTEGER,
                         reboot_counter INTEGER,
                         base_time INTEGER,
                         battery INTEGER,
                         light INTEGER,
                         thermistor INTEGER,
                         PRIMARY KEY (node_id, cookie))''',
              'toast_sample': '''CREATE TABLE toast_sample
                        (node_id INTEGER,
                         cookie INTEGER,
                         reboot_counter INTEGER,
                         base_time INTEGER,
                         toast_id NVARCHAR(128),
                         PRIMARY KEY (node_id, cookie))''',
              'sensor_sample': '''CREATE TABLE sensor_sample
                        (node_id INTEGER,
                         cookie INTEGER,
                         channel_number INTEGER,
                         sample INTEGER,
                         PRIMARY KEY (node_id, cookie,
                         channel_number))''',
              'toast_connection': '''CREATE TABLE toast_connection
                           (node_id INTEGER,
                            cookie INTEGER,
                            reboot_counter INTEGER,
                            time INTEGER,
                            toast_id NVARCHAR(128),
                            tlv BLOB,
                            PRIMARY KEY (node_id, cookie))''',
              'sensor_connection': '''CREATE TABLE sensor_connection
                           (node_id INTEGER,
                            cookie INTEGER,
                            channel_number INTEGER,
                            sensor_type INTEGER,
                            sensor_id INTEGER,
                            PRIMARY KEY (node_id, cookie,
                            channel_number))''',
              'toast_disconnection': '''CREATE TABLE toast_disconnection
                             (node_id INTEGER,
                              cookie INTEGER,
                              reboot_counter INTEGER,
                              time INTEGER,
                              toast_id NVARCHAR(128),
                              PRIMARY KEY (node_id, cookie))''',
              'phoenix_reference': '''CREATE TABLE phoenix_reference
                             (node1 INTEGER,
                              cookie INTEGER,
                              rc1 INTEGER,
                              ts1 INTEGER,
                              node2 INTEGER,
                              rc2 INTEGER,
                              ts2 INTEGER,
                              PRIMARY KEY (node1, cookie))''',
              'base_reference': '''CREATE TABLE base_reference
                             (node1 INTEGER,
                              rc1 INTEGER,
                              ts1 INTEGER,
                              unixTS REAL)''',
              'node_status': '''CREATE TABLE node_status
                             (node_id INTEGER,
                              ts REAL,
                              writeCookie INTEGER,
                              subnetChannel INTEGER,
                              sampleInterval INTEGER,
                              barcode_id NVARCHAR(128),
                              role INTEGER)''',
#               'bacon_id': '''CREATE TABLE bacon_id 
#                              (node_id INTEGER,
#                               cookie INTEGER,
#                               barcode_id TEXT,
#                               PRIMARY KEY (node_id, cookie))''',
              'bacon_settings': '''CREATE TABLE bacon_settings
                             (node_id INTEGER,
                              cookie INTEGER,
                              rc INTEGER,
                              ts INTEGER,
                              offset INTEGER,
                              data BLOB,
                              barcode_id NVARCHAR(128),
                              bacon_interval INTEGER,
                              toast_interval INTEGER,
                              low_push_threshold INTEGER,
                              high_push_threshold INTEGER,
                              probe_interval INTEGER,
                              global_channel INTEGER,
                              subnetwork_channel INTEGER,
                              router_channel INTEGER,
                              global_inv_freq INTEGER,
                              subnetwork_inv_freq INTEGER,
                              router_inv_freq INTEGER,
                              global_bw INTEGER,
                              subnetwork_bw INTEGER,
                              router_bw INTEGER,
                              global_md INTEGER,
                              subnetwork_md INTEGER,
                              router_md INTEGER,
                              global_wul INTEGER,
                              subnetwork_wul INTEGER,
                              router_wul INTEGER,
                              max_download_rounds INTEGER,
                              PRIMARY KEY (node_id, cookie))''',
              'active_period': '''CREATE TABLE active_period
                                    (master_id INTEGER,
                                     cookie INTEGER,
                                     rc INTEGER,
                                     ts INTEGER,
                                     network_segment INTEGER,
                                     channel INTEGER,
                                     PRIMARY KEY (master_id, cookie))''',
              'network_membership': '''CREATE TABLE network_membership
                                         (master_id INTEGER,
                                          cookie INTEGER,
                                          slave_id INTEGER,
                                          distance INTEGER,
                                          PRIMARY KEY (master_id,
                                          cookie, slave_id))''',
              'packet':'''CREATE TABLE packet
                            (src INTEGER, 
                             ts FLOAT, 
                             amId INTEGER, 
                             data BLOB)'''}
    views = {'last_ap':'''CREATE VIEW last_ap AS
                          SELECT master_id, network_segment, 
                            max(cookie) as cookie 
                          FROM active_period
                          GROUP BY master_id, network_segment''',
             'last_bs':'''CREATE VIEW last_bs AS
                          SELECT bs.node_id, max(cookie) as cookie 
                          FROM bacon_settings bs 
                          GROUP BY node_id''',
             'last_connection':'''CREATE VIEW last_connection AS
                          SELECT node_id, toast_id, 
                          max(cookie) as cookie
                          FROM toast_connection 
                          GROUP BY node_id, toast_id''',
             'last_disconnection':'''CREATE VIEW last_disconnection AS
                          SELECT node_id, toast_id, 
                          max(cookie) as cookie
                          FROM toast_disconnection 
                          GROUP BY node_id, toast_id''',
             'last_status': '''CREATE VIEW last_status AS
                          SELECT node_id, max(ts) as ts
                          FROM node_status
                          GROUP BY node_id'''}

    # class finds suitable filename for DB and creates tables if needed
    def __init__(self, rootName):
        # retry multiple filenames by incrementing counter in filename
        # a filename is accepted if either tables exists in it or 
        # tables can be created and the db passes an integrity check
        for fileCounter in range(0, DatabaseInit.FILE_RETRIES):
            dbFile = rootName + str(fileCounter) + '.sqlite'
            
            # test db for integrity
            try:
                connection = pyodbc.connect(connection_string)

                cursor = connection.cursor()
            except pyodbc.Error as ex:
                print "Unable to create db connection cursor: " + str(e)
                sys.stderr.write("Unable to create db connection cursor: " + str(ex)+ "\n")
                continue

            try:
                cursor.execute(' DBCC CHECKDB (' + db_name + ');')
                rows = cursor.fetchone()
            except Exception as ex:
                # database failed integrity check
                print "Database integrity error: " + str(ex)
                sys.stderr.write("Database integrity error: " + str(ex)+ "\n")
                continue

                # close file
                try:
                    cursor.close()
                    connection.close()
                except:
                    pass
            else:
                print "%s passed integrity check" % dbFile
                
            # clean up
            # note: this cannot be in a finally: statement since the connection migth already be closed
            try:
                cursor.close()
                connection.close()
            except:
                pass
                
            # check db for missing tables, create file if necessary 
            try:
                connection = sqlite3.connect(dbFile)
                cursor = connection.cursor()

                cursor.execute('''SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE';''')
                foundTables = dict(cursor.fetchall())
                for table in DatabaseInit.tables:
                    if table not in foundTables:
                        print "%s missing"%table
                        cursor.execute(DatabaseInit.tables[table])
                    else:
                        if foundTables[table] != DatabaseInit.tables[table]:
                            print "%s Found %s, expected %s"%(table, foundTables[table], DatabaseInit.tables[table])
                        else:
                            print "%s OK"%table
                cursor.execute('''SELECT * FROM INFORMATION_SCHEMA.VIEWS;''')
                foundViews = dict(cursor.fetchall())
                for view in DatabaseInit.views:
                    if view not in foundViews:
                        print "%s missing"%view
                        cursor.execute(DatabaseInit.views[view])
                    else:
                        if foundViews[view] != DatabaseInit.views[view]:
                            print "%s Found %s, expected %s"%(view, foundViews[view], DatabaseInit.views[view])
                        else:
                            print "%s OK"%view
                connection.commit();
                
            except Exception as e:
                sys.stderr.write("Error reading database: " + str(e)+ "\n")
                continue
            finally:
                cursor.close()
                connection.close()
                    
            # only set name if no exceptions thrown
            self.dbName = db_name
            break
            
        if self.dbName is None:
            raise IOError

    def getName(self):
        return self.dbName

# class test function
if __name__ == '__main__':

    try:
        db = DatabaseInit(db_name)
        print db.getName()
    except IOError:
        print "caught error"
    
    


