import Tkinter
from Tkinter import *


class DisplayFrame(Frame):

    def __init__(self, parent, hub, **args):
        Frame.__init__(self, parent, **args)
        
        self.hub = hub
        
        #self.initUI()
        self.frame = Frame(self)
        self.frame.grid(column=0, row=0)
    
    
    def updateAll(self):    
        #nodes = str(len(self.hub.node.leafs))
        
        self.nodes = self.hub.node.leafs.keys()
        
        # show UI
        self.frame.grid_forget()        
        self.frame = Frame(self)
        
        label = Label(self.frame, text="Update sample interval for all nodes")
        label.grid(column=0, row=0, columnspan=2, sticky=W)
        
        label = Label(self.frame, text="Number of nodes selected:")
        label.grid(column=0, row=1, sticky=E)

        label = Label(self.frame, text=str(len(self.nodes)))
        label.grid(column=1, row=1, sticky=E)

        label = Label(self.frame, text="New sample interval:")
        label.grid(column=0, row=2, sticky=E)
        
        self.sampleVar = StringVar()
        entry = Entry(self.frame, textvariable=self.sampleVar)
        entry.grid(column=1, row=2)
        
        button = Button(self.frame, text="Update", command=self.insertDict)
        button.grid(column=1, row=3)
        
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



    def updateAllType(self, type):
        """ Update the sample interval for nodes with a specific sensor type attached
        """
        
        # find nodes with specified sensor type
        multiplexers = self.hub.node.multiplexers
        
        self.nodes = []
        
        # plexer is a {node->list(multiplexer)}-map
        for node in multiplexers:
            multiplexerList = multiplexers[node]
            
            # plex is a list of multiplexers
            for multiplexer in multiplexerList:
                # each multiplexer is a tuble with multiplexer id and 8 sensor type channels
                for sensor in multiplexer[1:9]:
                    if sensor == type:
                        self.nodes.append(node)
        
        # show UI
        self.frame.grid_forget()
        self.frame = Frame(self)
        
        label = Label(self.frame, text="Update sample interval for nodes with sensor type: %s" % type)
        label.grid(column=0, row=0, columnspan=2, sticky=W)
        
        label = Label(self.frame, text="Number of nodes selected:")
        label.grid(column=0, row=1, sticky=E)

        label = Label(self.frame, text=str(len(self.nodes)))
        label.grid(column=1, row=1, sticky=E)

        label = Label(self.frame, text="New sample interval:")
        label.grid(column=0, row=2, sticky=E)
        
        self.sampleVar = StringVar()
        entry = Entry(self.frame, textvariable=self.sampleVar)
        entry.grid(column=1, row=2)
        
        button = Button(self.frame, text="Update", command=self.insertDict)
        button.grid(column=1, row=3)
        
        self.frame.grid(column=0, row=0)
    


    def updateSiteSite(self, site):
        """ Update the sample interval for nodes within a specific site.
        """
        
        self.nodes = []
        
        for leaf in self.hub.node.membership:
            print leaf
            if self.hub.node.membership[leaf] == site:
                self.nodes.append(leaf)
        
        
        # show UI
        self.frame.grid_forget()
        self.frame = Frame(self)
        
        label = Label(self.frame, text="Site: %X" % site)
        label.grid(column=0, row=0, columnspan=2, sticky=W)
        
        label = Label(self.frame, text="Number of nodes selected:")
        label.grid(column=0, row=1, sticky=E)

        label = Label(self.frame, text=str(len(self.nodes)))
        label.grid(column=1, row=1, sticky=E)

        label = Label(self.frame, text="New sample interval:")
        label.grid(column=0, row=2, sticky=E)
        
        self.sampleVar = StringVar()
        entry = Entry(self.frame, textvariable=self.sampleVar)
        entry.grid(column=1, row=2)
        
        button = Button(self.frame, text="Update", command=self.insertDict)
        button.grid(column=1, row=3)
        
        self.frame.grid(column=0, row=0)



    def updateSiteType(self, site, type):
        """ Update the sample interval for nodes with a specific sensor type attached in a specific site.
        """
        self.nodes = []
        
        # find nodes with specified sensor type
        multiplexers = self.hub.node.multiplexers
        

        # find leaf nodes in site
        for leaf in self.hub.node.membership:
            if self.hub.node.membership[leaf] == site:
                
                # plexer is a {node->list(multiplexer)}-map
                if leaf in multiplexers:
                    multiplexerList = multiplexers[leaf]
                    
                    # plex is a list of multiplexers
                    for multiplexer in multiplexerList:
                        # each multiplexer is a tuble with multiplexer id and 8 sensor type channels
                        for sensor in multiplexer[1:9]:
                            if sensor == type:
                                self.nodes.append(leaf)
        
        # show UI
        self.frame.grid_forget()
        self.frame = Frame(self)
        
        label = Label(self.frame, text="Update sample interval for nodes with sensor type: %s" % type)
        label.grid(column=0, row=0, columnspan=2, sticky=W)
        
        label = Label(self.frame, text="Number of nodes selected:")
        label.grid(column=0, row=1, sticky=E)

        label = Label(self.frame, text=str(len(self.nodes)))
        label.grid(column=1, row=1, sticky=E)

        label = Label(self.frame, text="New sample interval:")
        label.grid(column=0, row=2, sticky=E)
        
        self.sampleVar = StringVar()
        entry = Entry(self.frame, textvariable=self.sampleVar)
        entry.grid(column=1, row=2)
        
        button = Button(self.frame, text="Update", command=self.insertDict)
        button.grid(column=1, row=3)
        
        self.frame.grid(column=0, row=0)



    def updateRouter(self, router):
        """ Show Router information
        """
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



