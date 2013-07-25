from Tkinter import *


from DatabaseQuery import DatabaseQuery
from SettingsFile import SettingsFile


class NodeFrame(Frame):

    SETTINGS = "network.settings"
    DATABASE = "example.db"

    def __init__(self, parent, hub, **args):
        Frame.__init__(self, parent, **args)
        
        self.hub = hub
        
        self.tkobjects = {}
        self.sensorTypes = {}
        
        self.sf = SettingsFile(self.SETTINGS)
        self.db = DatabaseQuery(self.DATABASE)
        
        self.changedVar = BooleanVar()
        self.changedVar.set(False)
        self.changedVar.trace("w", self.settingsChanged)
        
        self.initUI()
        self.saveSettings()
    
    def loadSettings(self):
        self.offline = self.sf.read()        
        self.online = self.db.getSettings()
        self.plexer = self.db.getNetwork()
    
    def saveSettings(self):        
        self.sf.write(self.offline)
        self.changedVar.set(False)

    def settingsChanged(self, *args):
        if self.changedVar.get():
            pass
            # note: give visual cue that settings have changed
            #print "settings changed"

    def initUI(self):
        
        # load settings from database and from settings file
        self.loadSettings()
        
        # draw nodes that are already online
        for n, nodeid in enumerate(sorted(self.online.iterkeys())):
            #print "nodes: ", n, nodeid
            
            # if settings exist on file (offline) prioritize them instead
            if nodeid in self.offline:
                if self.online[nodeid] != self.offline[nodeid]:
                    self.online[nodeid] = self.offline[nodeid]
                    self.changedVar.set(True)
                
            label = "%s\n%s" % (nodeid, self.online[nodeid])
            
            button = Button(self, text=label, justify=RIGHT, command=lambda nodeid=nodeid: self.selectNode(nodeid))
            button.grid(column=0, row=n, sticky=N+S+E+W)
            self.tkobjects["nodeButton_%s" % nodeid] = button
            
            # if node has multiplexer(s) attached, draw multiplexer and sensor types
            if nodeid in self.plexer:
                # each node can have multiple multiplexers attached
                for i, plex in enumerate(self.plexer[nodeid]):
                    #print "plexs: ", i, plex[0]
                    plexid = plex[0]
                    frame = Frame(self, bd=1, relief=SUNKEN)
                    self.tkobjects["plexFrame_%s" % plexid] = frame
                    
                    button = Button(frame, text=plexid, command=lambda plexid=plexid: self.selectPlex(plexid))
                    button.grid(column=0, row=0, columnspan=8, sticky=N+S+E+W)
                    self.tkobjects["plexButton_%s" % plexid] = button
                    
                    # each multiplexer has 8 channels
                    for j, sensor in enumerate(plex[1:9]):
                        self.sensorTypes[sensor] = 1
                        
                        label = Label(frame, text=str(sensor), bd=1, relief=SUNKEN)
                        
                        label.grid(column=j, row=1, sticky=N+S+E+W)
                        self.tkobjects["sensLabel_%s_%d" % (plexid, j)] = label
                    
                    frame.grid(column=i+1, row=n)
            
        # draw remaining nodes from settings file
        for nodeid in sorted(self.offline.iterkeys()):
            #print "nodes: ", nodeid
            # check if node is in the online set
            if nodeid not in self.online:
                n += 1
                label = "%s\n%s" % (nodeid, self.offline[nodeid])
                button = Button(self, text=label, justify=RIGHT, command=lambda nodeid=nodeid: self.selectNode(nodeid))
                button.grid(column=0, row=n, sticky=N+S+E+W)
                self.tkobjects["nodeButton_%s" % nodeid] = button
            
        # update menu list of available sensor types
        self.hub.control.updateTypes(self.sensorTypes)
        
        # update dictionary with both offline and online nodes 
        # the settings file has higher priority than the online settings
        # i.e. manual changes in the file has higher priority
        for nodeid in self.online:
            if nodeid not in self.offline:
                print "insert: ", nodeid
                self.offline[nodeid] = self.online[nodeid]  
    
    def selectNode(self, barcode):
        self.hub.display.updateNode(barcode)

    def selectPlex(self, barcode):
        self.hub.display.infoPlex(barcode)






