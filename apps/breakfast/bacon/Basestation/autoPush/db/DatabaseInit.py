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

    # Table creation strings
    FLASH_TABLE_SQL = '''CREATE TABLE cookie_table
                         (node_id INTEGER NOT NULL,
                          base_time REAL,
                          cookie INTEGER NOT NULL,
                          nextCookie INTEGER,
                          length INTEGER,
                          retry INTEGER DEFAULT 0,
                          PRIMARY KEY (node_id, cookie));'''

    BACON_SAMPLE_SQL = '''CREATE TABLE bacon_sample
                        (node_id INTEGER,
                         cookie INTEGER,
                         reboot_counter INTEGER,
                         base_time INTEGER,
                         battery INTEGER,
                         light INTEGER,
                         thermistor INTEGER,
                         PRIMARY KEY (node_id, cookie));'''

    TOAST_SAMPLE_SQL = '''CREATE TABLE toast_sample
                        (node_id INTEGER,
                         cookie INTEGER,
                         reboot_counter INTEGER,
                         base_time INTEGER,
                         toast_id TEXT,
                         PRIMARY KEY (node_id, cookie));'''

    SENSOR_SAMPLE_SQL= '''CREATE TABLE sensor_sample
                        (node_id INTEGER,
                         cookie INTEGER,
                         channel_number INTEGER,
                         sample INTEGER,
                         PRIMARY KEY (node_id, cookie, channel_number));'''

    TOAST_CONNECTION_SQL= '''CREATE TABLE toast_connection
                           (node_id INTEGER,
                            cookie INTEGER,
                            reboot_counter INTEGER,
                            time INTEGER,
                            toast_id TEXT,
                            tlv BLOB,
                            PRIMARY KEY (node_id, cookie));'''

    SENSOR_CONNECTION_SQL='''CREATE TABLE sensor_connection
                           (node_id INTEGER,
                            cookie INTEGER,
                            channel_number INTEGER,
                            sensor_type INTEGER,
                            sensor_id INTEGER,
                            PRIMARY KEY (node_id, cookie, channel_number));'''

    TOAST_DISCONNECTION_SQL='''CREATE TABLE toast_disconnection
                             (node_id INTEGER,
                              cookie INTEGER,
                              reboot_counter INTEGER,
                              time INTEGER,
                              toast_id TEXT,
                              PRIMARY KEY (node_id, cookie));'''


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
                    cursor.execute(DatabaseInit.BACON_SAMPLE_SQL);
                    cursor.execute(DatabaseInit.TOAST_SAMPLE_SQL);
                    cursor.execute(DatabaseInit.SENSOR_SAMPLE_SQL);
                    cursor.execute(DatabaseInit.TOAST_CONNECTION_SQL);
                    cursor.execute(DatabaseInit.SENSOR_CONNECTION_SQL);
                    cursor.execute(DatabaseInit.TOAST_DISCONNECTION_SQL);
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
    
    


