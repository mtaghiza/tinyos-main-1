#!/usr/bin/env python

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
                         toast_id TEXT,
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
                            toast_id TEXT,
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
                              toast_id TEXT,
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
              'bacon_id': '''CREATE TABLE bacon_id 
                             (node_id INTEGER,
                              cookie INTEGER,
                              barcode_id TEXT,
                              PRIMARY KEY (node_id, cookie))''',
              'bacon_settings': '''CREATE TABLE bacon_settings
                             (node_id INTEGER,
                              cookie INTEGER,
                              rc INTEGER,
                              ts INTEGER,
                              offset INTEGER,
                              data BLOB,
                              bacon_interval INTEGER,
                              toast_interval INTEGER,
                              PRIMARY KEY (node_id, cookie))''' }

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
                cursor.execute('''SELECT name, sql FROM sqlite_master WHERE type == 'table' ''')
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
                connection.commit();
 
                # only set name if no exceptions thrown
                self.dbName = dbFile
            except sqlite3.Error as e:
                sys.stderr.write("Error reading file: " + dbFile + str(e)+ "\n")
                continue
            finally:
                cursor.close()
                connection.close()
            break
        if self.dbName is None:
            raise IOError

    def getName(self):
        return self.dbName

# class test function
if __name__ == '__main__':

    try:
        db = DatabaseInit('database')
        print db.getName()
    except IOError:
        print "caught error"
    
    


