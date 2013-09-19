#!/usr/bin/env python


from tools.labeler.DatabaseInit import DatabaseInit
from tools.labeler.DatabaseInsert import DatabaseInsert
from tools.labeler.DatabaseExport import DatabaseExport

class Database(object):

    def __init__(self):
        init = DatabaseInit('database')
        dbName = init.getName()

        self.insert = DatabaseInsert(dbName)
        self.export = DatabaseExport(dbName)
        

    def insertBacon(self, bacon):
        #print "Database.insertRecord()", threading.current_thread().name
        print bacon
        
        self.insert.insertBacon(bacon)        

    def insertToast(self, toast):
        print toast
        
        self.insert.insertToast(toast)

    def attachSensors(self, sensors):
        print sensors
        
        self.insert.attachSensors(sensors)

    def detachSensors(self, toast):
        self.insert.detachSensors(toast)

    def exportCSV(self):
        self.export.exportCSV()


if __name__ == '__main__':

    db = Database()

    missing_list = db.findMissing()

    for rec in missing_list:
        print rec
    
    







