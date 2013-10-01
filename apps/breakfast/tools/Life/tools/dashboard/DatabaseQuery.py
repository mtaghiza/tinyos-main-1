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
        ret = c.execute(query, (masterId,)).fetchone()
        if not ret:
            ret = (0, 0, 0)
        return ret

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
              barcode = "(?) %x"%(row[0])
          else:
            barcode = row[1]
          
          output[key] = (barcode, row[2])
        
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
              key = '(?) %x'%(row[4]) 
          else:
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
          SELECT bacon_settings.barcode_id, tc.node_id,
          tc.reboot_counter, tc.time, tc.cookie, tc.toast_id,
          sc.channel_number, sc.sensor_type, sc.sensor_id
          FROM (
          SELECT lc.node_id, lc.toast_id, 
            max(lc.cookie, coalesce(lb.cookie, -1), coalesce(ld.cookie, -1)) as cookie
          FROM last_connection lc 
          LEFT JOIN last_disconnection ld
            ON lc.node_id = ld.node_id 
               AND lc.toast_id = ld.toast_id
          LEFT JOIN last_bs lb
            ON lc.node_id = lb.node_id
            ) lr 
          JOIN toast_connection tc 
            ON lr.node_id = tc.node_id 
               AND lr.cookie = tc.cookie
          JOIN sensor_connection sc 
            ON sc.node_id = tc.node_id AND sc.cookie = tc.cookie
          JOIN last_bs on tc.node_id = last_bs.node_id
          JOIN bacon_settings on last_bs.node_id = bacon_settings.node_id AND
          last_bs.cookie = bacon_settings.cookie'''

        # sqlite connections can only be used from the same threads they are established from
        if self.connected == False:
            self.connected == True
            # raises sqlite3 exceptions
            self.connection = sqlite3.connect(self.dbName)
            self.connection.text_factory = str
            self.cursor = self.connection.cursor()

        self.cursor.execute(query)

        output = {}
        #sql query return 1 row per currently-connected sensor
        #we want to put this into a nested set of maps like this:
        #{
        #  bacon_barcode:{
        #    toast_barcode:{
        #      channel:(sensor_type, sensor_barcode)}
        #  }
        #}
        for row in self.cursor:
            baconBar = row[0]
            toastBar = row[5]
            cn = row[6]
            st = row[7]
            sid = row[8]
            output[baconBar] = output.get(baconBar, {})
            output[baconBar][toastBar] = output[baconBar].get(toastBar, {})
            output[baconBar][toastBar][cn]=(st, sid)
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
                output[channel] = (hex(row[1]), hex(row[2]))
        
        return output

    def contactSummary(self):
        now = time.time()
        #TODO: time since last contact
        #TODO: time since last bacon/toast sample
        #TODO: most recent battery voltage measurement


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
