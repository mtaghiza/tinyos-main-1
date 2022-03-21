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


import csv
import datetime
import pyodbc
from ..config import db_server_name, db_name


class DatabaseExport(object):

    def __init__(self, dbName):
        self.dbName = dbName
        self.connected = False

    def __del__(self):
        if self.connected == True:
            self.cursor.close()
            self.connection.close()
            
            print "closing connection"

    def exportCSV(self):

        # sqlite connections can only be used from the same threads they are established from
        if self.connected == False:
            self.connected == True
            # raises sqlite3 exceptions
            connection = pyodbc.connect('Driver={SQL Server};'
                                        'Server=' + db_server_name + ';'
                                        'Database=' + db_name + ';'
                                        'Trusted_Connection=yes;')
            self.cursor = self.connection.cursor()

        now = datetime.datetime.now()
        nowStr = now.strftime("%Y%m%dT%H%M%S")
        
        baconStr = 'bacon.' + nowStr + '.csv'
        toastStr = 'toast.' + nowStr + '.csv'
        sensorsStr = 'sensors.' + nowStr + '.csv'
        
        tableStr = ['bacon_table', 'toast_table', 'sensor_table']
        nameStr = [baconStr, toastStr, sensorsStr]
        
        for j in range(0,3):

            self.cursor.execute("select * from %s order by time;" % tableStr[j])

            with open(nameStr[j], 'wb') as csvfile:
                csvWriter = csv.writer(csvfile)
                csvWriter.writerow([i[0] for i in self.cursor.description]) # write headers
                csvWriter.writerows(self.cursor)



if __name__ == '__main__':

    from Database import Database 

    db = Database()

    db.exportCookie()

