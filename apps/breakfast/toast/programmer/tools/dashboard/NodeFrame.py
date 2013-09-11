import Tkinter
from Tkinter import *
from math import floor

import copy

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
        
        #self.sf = SettingsFile(self.SETTINGS)
        self.db = DatabaseQuery(self.DATABASE)
        
        self.changedVar = BooleanVar()
        self.changedVar.set(False)
        self.changedVar.trace("w", self.settingsChanged)
        
        self.channels = [0, 31, 63, 95, 159, 191, 223]
        #self.channels = self.binarySeparation()

        # load settings from database and from settings file
        self.loadSettings()        
        self.membership = {}
        self.requestedLeafs = {}
        
        self.initUI()
        self.saveSettings()
    
    def loadSettings(self):
        #self.offline = self.sf.read()        
        self.leafs = self.db.getLeafs()
        self.originalLeafs = copy.deepcopy(self.leafs)

        self.routers = self.db.getRouters()
        self.originalRouters = copy.deepcopy(self.routers)
        
        self.multiplexers = self.db.getMultiplexers()
    
    def saveSettings(self):        
        #self.sf.write(self.offline)
        self.changedVar.set(False)

    def settingsChanged(self, *args):
        if self.changedVar.get():
            pass
            # note: give visual cue that settings have changed
            #print "settings changed"

    def initUI(self):
        self.oldSuperFrame = Frame(self)
        self.oldSuperFrame.grid(column=0, row=0)
        self.redrawAllNodes()
        

    def redrawAllNodes(self):
        siteChannels = {}
        siteLeafs = {}
        siteRow = {}
        
        if self.hub.display is None:
            selection = []
        else:
            selection = self.hub.display.nodes
        
        print "selection: ", selection
        self.superFrame = Frame(self)
        
        # draw routers
        for rowNumber, router in enumerate(sorted(self.routers.iterkeys())):
            #print rowNumber, router
            
            barcode, channel = self.routers[router]
            
            # make channel-router map
            # default is first router on the channel
            if channel not in siteChannels:
                siteChannels[channel] = router
            
            siteLeafs[router] = 0
        
            frame = Frame(self.superFrame, bd=2, relief=RIDGE, padx=1, pady=1)
            subframe = Frame(frame, bd=1, relief=SUNKEN)
            
            barcode_text = "%s\nSite: %s" % (barcode, router)
            button = Button(subframe, text=barcode_text, width=18, justify=LEFT, command=lambda barcode=barcode: self.selectRouter(barcode))
            
            # color code button: grey=selected, yellow=modified
            if barcode in selection:
                colorCode = "grey"
            elif self.routers[router] != self.originalRouters[router]:
                colorCode = "yellow"
            else:
                colorCode = self.cget("bg")
            
            button.configure(background=colorCode, activebackground=colorCode, highlightbackground=colorCode)
            button.grid(column=0, row=0, columnspan=2, sticky=N+S+E+W)
            
            label_text = "Channel:"
            label = Label(subframe, text=label_text)
            label.configure(background=colorCode)
            label.grid(column=0, row=1, sticky=N+S+E+W)

            typeVar = StringVar()        
            typeVar.set(self.DEFAULT_CHANNEL)
            typeOption = OptionMenu(subframe, typeVar, [self.DEFAULT_CHANNEL])
            typeOption.configure(width=3, background=colorCode, activebackground=colorCode, highlightbackground=colorCode)
            typeOption.grid(column=1, row=1, sticky=N+S+E+W)

            menu = typeOption["menu"]
            menu.delete(0, "end")

            # populate menu with channels
            menu.add_command(label=channel, command=Tkinter._setit(typeVar, channel)) 
            typeVar.set(channel)
            
            for key in self.channels:
                menu.add_command(label=key, command=lambda router=router, key=key: self.updateRouter(router, key))
            
            subframe.grid(column=0, row=0, sticky=N+S+E+W)

            frame.grid(column=0, row=rowNumber, sticky=N+S+E+W)
            
            self.tkobjects["routerFrame_%s" % router] = frame
            self.tkobjects["routerButton_%s" % router] = button
            self.tkobjects["routerOption_%s" % router] = typeOption
            self.tkobjects["routerOptionVar_%s" % router] = typeVar
        
        
        # draw default frame for unassigned leafs
        frame = Frame(self.superFrame, bd=2, relief=RIDGE, padx=1, pady=1)
        button = Button(frame, text="", width=18, relief=FLAT)
        button.grid(column=0, row=0)
        button.configure(state=DISABLED)
        frame.grid(column=0, row=len(self.routers), sticky=N+S+E+W)            
        self.tkobjects["routerFrame_none"] = frame
        siteLeafs["none"] = 0
        
        
        # draw leaf nodes 
        for rowNumber, leaf in enumerate(sorted(self.leafs.iterkeys())):
            interval, channel = self.leafs[leaf]
            
            # if leaf in self.membership:
            # site = self.membership[leaf]    
            if leaf in self.membership:
                site = self.membership[leaf]
                rowNumber = siteLeafs[site]
                siteLeafs[site] = rowNumber + 1
                
            elif channel in siteChannels:                        
                # if node not in membership table 
                # assign node to first router with same channel
                site = siteChannels[channel]
                rowNumber = siteLeafs[site]
                siteLeafs[site] = rowNumber + 1
                self.membership[leaf] = site
            else:
                site = "none"
                rowNumber = siteLeafs[site]
                siteLeafs[site] = rowNumber + 1
                self.membership[leaf] = site
            
            #frame = Frame(self.superFrame, bd=1, relief=SUNKEN)
            frame = self.tkobjects["routerFrame_%s" % site]
            
            subframe = Frame(frame, bd=1, relief=SUNKEN)
            button_text = "%s\nSampling: %s" % (leaf, interval)            
            button = Button(subframe, text=button_text, width=18, justify=LEFT, command=lambda leaf=leaf: self.selectNode(leaf))

            # color code button: grey=selected, yellow=modified
            if leaf in selection:
                colorCode = "grey"
            elif self.leafs[leaf] != self.originalLeafs[leaf]:
                colorCode = "yellow"
            else:
                colorCode = self.cget("bg")
            
            button.configure(background=colorCode, activebackground=colorCode, highlightbackground=colorCode)            
            button.grid(column=0, row=0, columnspan=2, sticky=N+S+E+W)
            
            label = Label(subframe, text="Site:", bd=0, relief=SUNKEN)
            label.configure(background=colorCode)            
            label.grid(column=0, row=1, sticky=N+S+E+W)

            typeVar = StringVar()        
            typeVar.set(site)
            typeOption = OptionMenu(subframe, typeVar, [site])
            typeOption.configure(width=3, background=colorCode, activebackground=colorCode, highlightbackground=colorCode)
            typeOption.grid(column=1, row=1, sticky=N+S+E+W)

            menu = typeOption["menu"]
            menu.delete(0, "end")
            
            # populate menu
            for site in sorted(self.routers.iterkeys()):
                #menu.add_command(label=site, command=Tkinter._setit(typeVar, site)) 
                menu.add_command(label=site, command=lambda leaf=leaf, site=site: self.updateLeaf(leaf,site))
       
            subframe.grid(column=1, row=rowNumber, sticky=N+S+E+W)
            
            self.tkobjects["nodeFrame_%s" % leaf] = subframe
            self.tkobjects["nodeButton_%s" % leaf] = button
            self.tkobjects["nodeOption_%s" % leaf] = typeOption
            self.tkobjects["nodeOptionVar_%s" % leaf] = typeVar
            
            # if node has multiplexer(s) attached, draw multiplexer and sensor types
            if leaf in self.multiplexers:
                # each node can have multiple multiplexers attached
                for i, plex in enumerate(self.multiplexers[leaf]):
                    print "plexs: ", i, plex[0]
                    plexid = plex[0]
                    subframe = Frame(frame, bd=1, relief=SUNKEN)
                    self.tkobjects["plexFrame_%s" % plexid] = frame
                    
                    # color code button: grey=selected, yellow=modified
                    if plexid in selection:
                        colorCode = "grey"
                    #elif self.leafs[leaf] != self.originalLeafs[leaf]:
                    #    colorCode = "yellow"
                    else:
                        colorCode = self.cget("bg")
                    
                    button = Button(subframe, text=plexid, command=lambda plexid=plexid: self.selectPlex(plexid))
                    button.configure(width=18, height=2, background=colorCode, activebackground=colorCode, highlightbackground=colorCode)
                    button.grid(column=0, row=0, columnspan=8, sticky=N+S+E+W)
                    self.tkobjects["plexButton_%s" % plexid] = button
                    
                    # each multiplexer has 8 channels
                    for j, sensor in enumerate(plex[1:9]):
                        self.sensorTypes[sensor] = 1
                        
                        label = Label(subframe, text=str(sensor), bd=1, relief=SUNKEN)
                        label.configure(background=colorCode, activebackground=colorCode, highlightbackground=colorCode)
                        label.grid(column=j, row=1, sticky=N+S+E+W)
                        self.tkobjects["sensLabel_%s_%d" % (plexid, j)] = label
                    
                    subframe.grid(column=i+2, row=rowNumber)
            
#        # draw remaining nodes from settings file
#        for barcode in sorted(self.offline.iterkeys()):
#            #print "nodes: ", barcode
#            # check if node is in the online set
#            if barcode not in self.leafs:
#                n += 1
#                label = "%s\n%s" % (barcode, self.offline[barcode])
#                button = Button(self.superFrame, text=label, justify=RIGHT, width=18, command=lambda barcode=barcode: self.selectNode(barcode))
#                button.grid(column=0, row=n, sticky=N+S+E+W)
#                self.tkobjects["nodeButton_%s" % barcode] = button
#            
        # update menu list of available sensor types
        self.hub.control.updateTypes(self.sensorTypes)
        self.hub.control.updateSites(self.routers)
#        
#        # update dictionary with both offline and online nodes 
#        # the settings file has higher priority than the online settings
#        # i.e. manual changes in the file has higher priority
#        for barcode in self.leafs:
#            if barcode not in self.offline:
#                print "insert: ", barcode
#                self.offline[barcode] = self.leafs[barcode]  

        # swap frames
        self.superFrame.grid(column=0, row=0)
        self.oldSuperFrame.grid_forget()
        self.oldSuperFrame = self.superFrame


    def selectNode(self, barcode):
        # don't mix router and multiplexer selections with leaf node selections
        if self.hub.display.currentView == "router" or self.hub.display.currentView == "plex":
            self.hub.display.nodes = []

        # control key adds/removes single leaf to/from selection
        if self.hub.controlKey == True:
            if barcode in self.hub.display.nodes:
                self.hub.display.nodes.remove(barcode)
            else:
                self.hub.display.nodes.append(barcode)
                
        # shift key adds/removes range of leaf nodes to/from selection
        elif self.hub.shiftKey == True:
            if barcode in self.hub.display.nodes:
                # deselect all nodes from the same site
                # between the one node clicked on 
                # and the top most selected node
                for leaf in reversed(sorted(self.hub.display.nodes)):
                    if leaf > barcode:
                        self.hub.display.nodes.remove(leaf)
                    else:
                        break
            else:
                # select all nodes from the same site
                # between the one node clicked on 
                # and another selected node
                # with smaller barcode id
                for leaf in reversed(sorted(self.membership.keys())):
                    
                    if leaf >= barcode:
                    # leaf has larger id than the one clicked
                        pass
                    elif self.membership[leaf] == self.membership[barcode] and leaf not in self.hub.display.nodes:
                        self.hub.display.nodes.append(leaf)
                    elif self.membership[leaf] == self.membership[barcode] and leaf in self.hub.display.nodes:
                    # this is the first leaf with smaller barcode id, 
                    # from the same site, that has already been selected
                    # break for loop
                        break
                    else:
                    # leaf is not from same site, skip
                        pass
                    
                # add self
                self.hub.display.nodes.append(barcode)
            
        # default, select single leaf node
        else:
            self.hub.display.nodes = [barcode]
        
        self.hub.display.updateNode()
        self.redrawAllNodes()

    def selectRouter(self, barcode):
        self.hub.display.nodes = [barcode]
        self.hub.display.updateRouter(barcode)
        self.redrawAllNodes()
    
    def selectPlex(self, barcode):
        self.hub.display.nodes = [barcode]
        self.hub.display.infoPlex(barcode)
        self.redrawAllNodes()


    def updateRouter(self, router, channel):
        typeVar = self.tkobjects["routerOptionVar_%s" % router] 
        typeVar.set(channel)

        barcode, oldChannel = self.routers[router]
        self.routers[router] = (barcode, channel)

        for leaf in self.leafs:
            interval, leafChannel = self.leafs[leaf]
            
            if leafChannel == oldChannel:
                self.leafs[leaf] = (interval, channel)

        self.redrawAllNodes()

    def updateLeaf(self, leaf, site):
        typeVar = self.tkobjects["nodeOptionVar_%s" % leaf]
        typeVar.set(site)

        router, newChannel = self.routers[site]
        interval, oldChannel = self.leafs[leaf]
        self.leafs[leaf] = (interval, newChannel)
        
        self.membership[leaf] = site
        
        self.hub.display.redrawAll()
        self.redrawAllNodes()

