import Tkinter
from Tkinter import *


class DisplayFrame(Frame):

    def __init__(self, parent, hub, **args):
        Frame.__init__(self, parent, **args)
        
        self.hub = hub
        
        self.currentType = "All Types"
        self.currentSite = "All Sites"
        self.currentView = None
        self.nodes = []
        
        #self.initUI()
        self.frame = Frame(self)
        self.frame.grid(column=0, row=0)
    
    
    #def insertAll(self):
    #    """ Update sample interval for all nodes in network.
    #    """
    #    interval = int(self.sampleVar.get())
    #    self.sampleVar.set("")
    #    
    #    for node in self.hub.node.leafs:
    #        (oldInterval, oldChannel) = self.hub.node.leafs[node]
    #        self.hub.node.leafs[node] = (interval, oldChannel)
    #    
    #    self.hub.node.saveSettings()
    #    self.hub.node.redrawAllNodes()



    def updateType(self, type):
        """ Update the sample interval for nodes with a specific sensor type attached
        """        
        self.currentType = type

    def updateSite(self, site):
        """ Update the sample interval for nodes with a specific sensor type attached
        """
        self.currentSite = site
        self.currentView = "multi"

    def updateSelection(self):    
        multiplexers = self.hub.node.multiplexers
        membership = self.hub.node.membership
        
        # store final selection in this list
        self.nodes = []

        # membership key contains all detected leaf nodes
        for leaf in membership:
            # only select node if site is correct or all sites are selected
            if (self.currentSite == str(membership[leaf])) or (self.currentSite == "All Sites"):
                
                # add node to final selection map if all types are selected
                if self.currentType == "All Types":
                    self.nodes.append(leaf)
                else:
                    # go through list of attached multiplexer boards 
                    # and see if any attached sensors match the selected type
                    # plexer is a {node->list(multiplexer)}-map
                    if leaf in multiplexers:
                        multiplexerList = multiplexers[leaf]
                        
                        # plex is a list of multiplexers
                        for multiplexer in multiplexerList:
                            # each multiplexer is a tuble with multiplexer id and 8 sensor type channels
                            for sensor in multiplexer[1:9]:
                                print leaf, sensor
                                if self.currentType == str(sensor):
                                    self.nodes.append(leaf)


    def redrawAll(self):
    
        if self.currentView == "multi":
            self.updateSelection()

            # show UI
            self.frame.grid_forget()
            self.frame = Frame(self)
            
            label = Label(self.frame, text="Update sample interval for nodes:")
            label.grid(column=0, row=0, columnspan=2, sticky=W)

            label = Label(self.frame, text="Site: %s" % self.currentSite)
            label.grid(column=0, row=1, columnspan=2, sticky=W)
            
            label = Label(self.frame, text="Type: %s" % self.currentType)
            label.grid(column=0, row=2, columnspan=2, sticky=W)
            
            label = Label(self.frame, text="Number of nodes selected:")
            label.grid(column=0, row=3, sticky=E)

            label = Label(self.frame, text=str(len(self.nodes)))
            label.grid(column=1, row=3, sticky=E)

            label = Label(self.frame, text="New sample interval:")
            label.grid(column=0, row=4, sticky=E)
            
            self.sampleVar = StringVar()
            entry = Entry(self.frame, textvariable=self.sampleVar)
            entry.grid(column=1, row=4)
            
            button = Button(self.frame, text="Update", command=self.insertDict)
            button.grid(column=1, row=5)
            
            self.frame.grid(column=0, row=0)
    




    def updateRouter(self, router):
        """ Show Router information
        """
        
        self.currentView = "router"
        
        # show UI
        self.frame.grid_forget()
        self.frame = Frame(self)
        
        label = Label(self.frame, text="Router information")
        label.grid(column=0, row=0, columnspan=2, sticky=W)
        
        label = Label(self.frame, text="Node ID:")
        label.grid(column=0, row=1, sticky=E)

        label = Label(self.frame, text=router)
        label.grid(column=1, row=1, sticky=E)

        
        self.frame.grid(column=0, row=0)


    def updateNode(self, node):
        """ Update the sample interval for single node.
        """
        
        self.currentView = "node"
        self.nodes = [ node ]
        
        # show UI
        self.frame.grid_forget()
        self.frame = Frame(self)
        
        label = Label(self.frame, text="Update sample interval")
        label.grid(column=0, row=0, columnspan=2, sticky=W)
        
        label = Label(self.frame, text="Node ID:")
        label.grid(column=0, row=1, sticky=E)

        label = Label(self.frame, text=node)
        label.grid(column=1, row=1, sticky=E)

        label = Label(self.frame, text="New sample interval:")
        label.grid(column=0, row=2, sticky=E)
        
        self.sampleVar = StringVar()
        entry = Entry(self.frame, textvariable=self.sampleVar)
        entry.grid(column=1, row=2)
        
        button = Button(self.frame, text="Update", command=self.insertDict)
        button.grid(column=1, row=3)
        
        self.frame.grid(column=0, row=0)

    
    def insertDict(self):
        """ Update global node dictionary, save it to settings file and update UI
        """
        print self.nodes
        try:
            interval = int(self.sampleVar.get())
        except ValueError:
            pass
        else:        
            for node in self.nodes:
                if node in self.hub.node.leafs:
                    (oldInterval, oldChannel) = self.hub.node.leafs[node]
                    self.hub.node.leafs[node] = (interval, oldChannel)
            
            self.hub.node.saveSettings()
            self.hub.node.redrawAllNodes()
        finally:
            self.sampleVar.set("")


    def infoPlex(self, plex):
        """ Show information about multiplexer.
        """
        
        self.currentView = "plex"
        info = self.hub.node.db.getPlex(plex)
        
        
        # show UI
        self.frame.grid_forget()
        self.frame = Frame(self)
        
        label = Label(self.frame, text="Multiplexer selected")
        label.grid(column=0, row=0, columnspan=2, sticky=W)
        
        label = Label(self.frame, text="Multiplexer ID:")
        label.grid(column=0, row=1, sticky=E)

        label = Label(self.frame, text=plex)
        label.grid(column=1, row=1, sticky=E)

        idFrame = Frame(self.frame)
        label = Label(idFrame, text="Channel")
        label.grid(column=0, row=0)
        label = Label(idFrame, text="Type")
        label.grid(column=1, row=0)
        label = Label(idFrame, text="ID")
        label.grid(column=2, row=0)

        line = 1
        for i in range(0,8):
            (type, id) = info[i]
            if type is not None:
                Label(idFrame, text=str(i+1)).grid(column=0, row=line)
                Label(idFrame, text=type).grid(column=1, row=line)
                Label(idFrame, text=id).grid(column=2, row=line)
                line += 1
        
        idFrame.grid(column=0, row=2, columnspan=2, sticky=W)
        
        self.frame.grid(column=0, row=0)



