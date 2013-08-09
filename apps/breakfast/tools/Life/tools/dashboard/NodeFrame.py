import Tkinter
from Tkinter import *
from math import floor

from tools.dashboard.DatabaseQuery import DatabaseQuery
from tools.dashboard.SettingsFile import SettingsFile


class NodeFrame(Frame):

    SETTINGS = "network.settings"
    DATABASE = "database0.db"
    #DATABASE = "example.db"
    DEFAULT_CHANNEL = "0"
    
    def __init__(self, parent, hub, **args):
        Frame.__init__(self, parent, **args)
        
        self.hub = hub
        
        self.tkobjects = {}
        self.sensorTypes = {}
        self.sites = []
        
        self.sf = SettingsFile(self.SETTINGS)
        self.db = DatabaseQuery(self.DATABASE)
        
        self.changedVar = BooleanVar()
        self.changedVar.set(False)
        self.changedVar.trace("w", self.settingsChanged)
        
        self.channels = [0, 31, 63, 95, 159, 191, 223]
        #self.channels = self.binarySeparation()
        
        self.initUI()
        self.saveSettings()
    
    def loadSettings(self):
        self.offline = self.sf.read()        
        self.online = self.db.getSettings()
        self.plexer = self.db.getNetwork()
        self.routers = self.db.getRouters()
    
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
        
        
        # routers, sort by channel and id
        # for each channel, draw frame
        # put routers with same channel in same frame

        # draw routers
        for n, router in enumerate(sorted(self.routers.iterkeys())):
            #print "nodes: ", n, router
            frame = Frame(self, bd=2, relief=RIDGE, padx=1, pady=1)
            
            self.sites.append(router)            
            barcode, channel = self.routers[router]
            
            
            subframe = Frame(frame, bd=1, relief=SUNKEN)
            
            barcode_text = "%s\nSite: %s" % (barcode, router)
            button = Button(subframe, text=barcode_text, width=18, justify=LEFT, command=lambda barcode=barcode: self.selectRouter(barcode))
            button.grid(column=0, row=0, columnspan=2, sticky=N+S+E+W)
            
            label_text = "Channel:"
            label = Label(subframe, text=label_text)
            label.grid(column=0, row=1, sticky=N+S+E+W)

            typeVar = StringVar()        
            typeVar.set(self.DEFAULT_CHANNEL)
            typeOption = OptionMenu(subframe, typeVar, [self.DEFAULT_CHANNEL])
            typeOption.configure(width=3)
            typeOption.grid(column=1, row=1, sticky=N+S+E+W)

            menu = typeOption["menu"]
            menu.delete(0, "end")

            # populate menu with channels
            menu.add_command(label=channel, command=Tkinter._setit(typeVar, channel)) 
            typeVar.set(channel)
            
            for key in self.channels:
                menu.add_command(label=key, command=Tkinter._setit(typeVar, key)) 
        
            subframe.grid(column=0, row=0, sticky=N+S+E+W)

            frame.grid(column=0, row=n, sticky=N+S+E+W)
            
            self.tkobjects["routerFrame_%s" % router] = frame
            self.tkobjects["routerButton_%s" % router] = button
            self.tkobjects["routerOption_%s" % router] = typeOption
            self.tkobjects["routerOptionVar_%s" % router] = typeVar
            
        
        # nodes, sort by channel and id
        # for each node, put node in frame with same channel
        # if no frame, put in default frame
        
        
        # draw nodes that are already online
        for n, nodeid in enumerate(sorted(self.online.iterkeys())):
            
#            # if settings exist on file (offline) prioritize them instead
#            if nodeid in self.offline:
#                if self.online[nodeid] != self.offline[nodeid]:
#                    self.online[nodeid] = self.offline[nodeid]
#                    self.changedVar.set(True)
#                
            barcode, interval, channel = self.online[nodeid]
            site = "1"
            
            #frame = Frame(self, bd=1, relief=SUNKEN)
            frame = self.tkobjects["routerFrame_%s" % site]
            
            subframe = Frame(frame, bd=1, relief=SUNKEN)
            button_text = "%s\nSampling: %s" % (barcode, channel)            
            button = Button(subframe, text=button_text, width=18, justify=LEFT, command=lambda barcode=barcode: self.selectNode(barcode))
            button.grid(column=0, row=0, columnspan=2, sticky=N+S+E+W)
            
            label = Label(subframe, text="Site:", bd=0, relief=SUNKEN)
            label.grid(column=0, row=1, sticky=N+S+E+W)

            typeVar = StringVar()        
            typeVar.set(site)
            typeOption = OptionMenu(subframe, typeVar, [site])
            typeOption.configure(width=3)
            typeOption.grid(column=1, row=1, sticky=N+S+E+W)

            menu = typeOption["menu"]
            menu.delete(0, "end")
            
            # populate menu
            for site in self.sites:
                menu.add_command(label=site, command=Tkinter._setit(typeVar, site)) 
       
            subframe.grid(column=1, row=n, sticky=N+S+E+W)
            
            self.tkobjects["nodeFrame_%s" % nodeid] = subframe
            self.tkobjects["nodeButton_%s" % nodeid] = button
            self.tkobjects["nodeOption_%s" % nodeid] = typeOption
            self.tkobjects["nodeOptionVar_%s" % nodeid] = typeVar
            
            # if node has multiplexer(s) attached, draw multiplexer and sensor types
            if barcode in self.plexer:
                # each node can have multiple multiplexers attached
                for i, plex in enumerate(self.plexer[barcode]):
                    print "plexs: ", i, plex[0]
                    plexid = plex[0]
                    subframe = Frame(frame, bd=1, relief=SUNKEN)
                    self.tkobjects["plexFrame_%s" % plexid] = frame
                    
                    button = Button(subframe, text=plexid, command=lambda plexid=plexid: self.selectPlex(plexid))
                    button.configure(width=18, height=2)
                    button.grid(column=0, row=0, columnspan=8, sticky=N+S+E+W)
                    self.tkobjects["plexButton_%s" % plexid] = button
                    
                    # each multiplexer has 8 channels
                    for j, sensor in enumerate(plex[1:9]):
                        self.sensorTypes[sensor] = 1
                        
                        label = Label(subframe, text=str(sensor), bd=1, relief=SUNKEN)
                        label.grid(column=j, row=1, sticky=N+S+E+W)
                        self.tkobjects["sensLabel_%s_%d" % (plexid, j)] = label
                    
                    subframe.grid(column=i+2, row=n)
            
#        # draw remaining nodes from settings file
#        for nodeid in sorted(self.offline.iterkeys()):
#            #print "nodes: ", nodeid
#            # check if node is in the online set
#            if nodeid not in self.online:
#                n += 1
#                label = "%s\n%s" % (nodeid, self.offline[nodeid])
#                button = Button(self, text=label, justify=RIGHT, width=18, command=lambda nodeid=nodeid: self.selectNode(nodeid))
#                button.grid(column=0, row=n, sticky=N+S+E+W)
#                self.tkobjects["nodeButton_%s" % nodeid] = button
#            
        # update menu list of available sensor types
        self.hub.control.updateTypes(self.sensorTypes)
#        
#        # update dictionary with both offline and online nodes 
#        # the settings file has higher priority than the online settings
#        # i.e. manual changes in the file has higher priority
#        for nodeid in self.online:
#            if nodeid not in self.offline:
#                print "insert: ", nodeid
#                self.offline[nodeid] = self.online[nodeid]  

    def selectRouter(self, barcode):
        self.hub.display.updateRouter(barcode)
    
    def selectNode(self, barcode):
        self.hub.display.updateNode(barcode)

    def selectPlex(self, barcode):
        self.hub.display.infoPlex(barcode)

    def binarySeparation(self):
        channels = range(0,256)
        n = 256
        map = { 0:1 }
        output = [0]
        
        while(n >= 1):
            m = 256 / n
            
            for i in range(1,m+1):
                key = n*i-1
                
                if key not in map:
                    map[key] = 1
                    output.append(key)
                
            n = n/2
        
        return output



