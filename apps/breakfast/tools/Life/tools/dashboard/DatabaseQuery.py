#!/usr/bin/env python

import sqlite3

import tools.cx.constants as constants

class DatabaseQuery(object):

    def __init__(self, dbName):
        self.dbName = dbName
        self.connected = False
        print "DBQ %s"%(dbName)
        

    def __del__(self):
        if self.connected == True:
            self.cursor.close()
            self.connection.close()
            
            print "closing connection" 

    def getLastDownloadResults(self, masterId):
        query = ''' SELECT lastDownload.master_id, reachedCount.cnt, allCount.cnt
          FROM 
          (select master_id, max(cookie) as cookie FROM active_period WHERE master_id = ? GROUP BY master_id) as lastDownload
          JOIN 
          (select master_id, cookie, count(*) as cnt FROM network_membership GROUP BY master_id, cookie) as allCount
          ON lastDownload.master_id = allCount.master_id AND lastDownload.cookie = allCount.cookie
          JOIN 
          (select master_id, cookie, count(*) as cnt FROM network_membership WHERE distance < 255 GROUP BY master_id, cookie) as reachedCount
          ON lastDownload.master_id = reachedCount.master_id AND lastDownload.cookie = reachedCount.cookie
        '''
        c = sqlite3.connect(self.dbName)
        return c.execute(query, (masterId,)).fetchone()

    def getRouters(self):
        """
        Get list of routers in range of basestation.
        """
        
        query = '''
          SELECT nm.slave_id, 
            coalesce(bs.barcode_id, 'X'), 
            coalesce(bs.subnetwork_channel, ?), 
            nm.master_id, 
            ap.network_segment
          FROM last_ap
          JOIN active_period ap 
            ON last_ap.master_id = ap.master_id 
            AND last_ap.cookie = ap.cookie
          JOIN network_membership nm 
            ON nm.master_id = last_ap.master_id 
            AND nm.cookie = last_ap.cookie
          LEFT JOIN last_bs 
            ON nm.slave_id = last_bs.node_id
          LEFT JOIN bacon_settings bs
            ON last_bs.node_id = bs.node_id 
            AND last_bs.cookie=bs.cookie
          WHERE ap.network_segment = ?
            AND nm.slave_id != nm.master_id'''
        
        # sqlite connections can only be used from the same threads they are established from
        if self.connected == False:
            self.connected == True
            # raises sqlite3 exceptions
            self.connection = sqlite3.connect(self.dbName)
            self.connection.text_factory = str
            self.cursor = self.connection.cursor()

        self.cursor.execute(query,
          (constants.CHANNEL_SUBNETWORK_DEFAULT, constants.NS_ROUTER,))

        output = {}
        for row in self.cursor:
          key = "%04x" % int(row[0])
          if row[1] == 'X':
              row[1] = "(?) %x"%(row[0])
          data = row[1:3]
          
          output[key] = data
        
        return output


    def getLeafs(self):
        """
        Get the latest downloaded settings from all the Nodes in the network.
        This is complimentary to what is found in the network.settings file.
        """
        
        query ='''SELECT  
            coalesce(bs.barcode_id, 'X') as barcode_id, 
            coalesce(bs.toast_interval, 0) as toast_interval, 
            coalesce(bs.subnetwork_channel, ?) as subnetwork_channel, 
            coalesce(bs.cookie, 0) as cookie,
            nm.slave_id, nm.master_id, 
            ap.network_segment
          FROM last_ap
          JOIN active_period ap 
            ON last_ap.master_id = ap.master_id 
            AND last_ap.cookie = ap.cookie
          JOIN network_membership nm 
            ON nm.master_id = last_ap.master_id 
            AND nm.cookie = last_ap.cookie
          LEFT JOIN last_bs 
            ON nm.slave_id = last_bs.node_id
          LEFT JOIN bacon_settings bs
            ON last_bs.node_id = bs.node_id 
            AND last_bs.cookie=bs.cookie
          WHERE ap.network_segment = ?
            AND nm.slave_id != nm.master_id;
        '''
        
        # sqlite connections can only be used from the same threads they are established from
        if self.connected == False:
            self.connected == True
            # raises sqlite3 exceptions
            self.connection = sqlite3.connect(self.dbName)
            self.connection.text_factory = str
            self.cursor = self.connection.cursor()
        
        self.cursor.execute(query,
          (constants.CHANNEL_SUBNETWORK_DEFAULT, constants.NS_SUBNETWORK,))

        output = {}
        for row in self.cursor:
          if row[0] == 'X':
              row[0] = '(?) %x'%(row[4]) 
          key = row[0]
          output[key] = row[1:3]
        
        return output

   
    def getMultiplexers(self):
        """
        Get the current view of the network, i.e., what Nodes are available, 
        what Multiplexers do they have attached, and what sensor types are 
        connected to the Multiplexers.
        """
        
        query = '''
                    SELECT c.bacon_id, c.toast_id
                    , MAX(CASE WHEN d.channel_number = 0 THEN d.sensor_type ELSE 0 END) AS channel0
                    , MAX(CASE WHEN d.channel_number = 1 THEN d.sensor_type ELSE 0 END) AS channel1
                    , MAX(CASE WHEN d.channel_number = 2 THEN d.sensor_type ELSE 0 END) AS channel2
                    , MAX(CASE WHEN d.channel_number = 3 THEN d.sensor_type ELSE 0 END) AS channel3
                    , MAX(CASE WHEN d.channel_number = 4 THEN d.sensor_type ELSE 0 END) AS channel4
                    , MAX(CASE WHEN d.channel_number = 5 THEN d.sensor_type ELSE 0 END) AS channel5
                    , MAX(CASE WHEN d.channel_number = 6 THEN d.sensor_type ELSE 0 END) AS channel6
                    , MAX(CASE WHEN d.channel_number = 7 THEN d.sensor_type ELSE 0 END) AS channel7
                    FROM
                    (
                        SELECT a.barcode_id AS bacon_id, a.node_id AS node_id, b.toast_id AS toast_id, b.cookie AS cookie
                        FROM 
                        bacon_settings AS a,
                        (
                            SELECT node_id, toast_id, cookie, 'c' AS type FROM toast_connection
                            UNION
                            SELECT node_id, toast_id, cookie, 'd' AS type FROM toast_disconnection
                            ORDER BY cookie ASC
                        ) AS b
                        WHERE a.node_id = b.node_id
                        GROUP BY toast_id
                        HAVING type = 'c'
                    ) AS c
                    LEFT JOIN sensor_connection AS d 
                    ON c.node_id = d.node_id AND c.cookie = d.cookie 
                    GROUP BY toast_id
                    '''
            
        # sqlite connections can only be used from the same threads they are established from
        if self.connected == False:
            self.connected == True
            # raises sqlite3 exceptions
            self.connection = sqlite3.connect(self.dbName)
            self.connection.text_factory = str
            self.cursor = self.connection.cursor()

        self.cursor.execute(query)

        output = {}
        for row in self.cursor:
            print row
            if len(row) == 10:
                if row[0] is not None:
                    key = row[0]
                    data = row[1:10]
                    
                    if key in output:
                        list = output[key]
                        list.append(data)
                        output[key] = list
                    else:
                        output[key] = [data]
        
        return output

    def getPlex(self, plex):
        """ Get information about multiplexer.
        """
        query = """ SELECT channel_number, sensor_type, sensor_id
                    FROM 
                    (
                        SELECT node_id, max(cookie) AS cookie
                        FROM toast_connection 
                        WHERE toast_id = '%s'
                    ) AS c
                    LEFT JOIN sensor_connection AS d 
                    ON c.node_id = d.node_id AND c.cookie = d.cookie """ % plex
        
        # sqlite connections can only be used from the same threads they are established from
        if self.connected == False:
            self.connected == True
            # raises sqlite3 exceptions
            self.connection = sqlite3.connect(self.dbName)
            self.connection.text_factory = str
            self.cursor = self.connection.cursor()

        self.cursor.execute(query)

        #output = [("",""), ("",""), ("",""), ("",""), ("",""), ("",""), ("",""), ("","")]
        output = [(None,None), (None,None), (None,None), (None,None), (None,None), (None,None), (None,None), (None,None)]
        for row in self.cursor:
            if row[0] is not None:
                channel = int(row[0])
                output[channel] = (row[1], row[2])
        
        return output


if __name__ == '__main__':
    db = DatabaseQuery("database0.sqlite")
    print "Leafs:",db.getLeafs()
    print "Routers:",db.getRouters()
    print "LDR:",db.getLastDownloadResults(61)
    
#     network = db.getNetwork()
# 
#     #for node in network:
#         #print node, network[node]
#         #for plex in network[node]:
#         #    print node, plex
# 
#     settings = db.getSettings()
# 
#     for i, n in enumerate(sorted(settings.iterkeys())):
#         print i, n
#     
#     #for node in settings:
#     #    print node, settings[node]
#     
