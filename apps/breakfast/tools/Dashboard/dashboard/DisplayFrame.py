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
        nodes = str(len(self.hub.node.offline))
        
        # show UI
        self.frame.grid_forget()        
        self.frame = Frame(self)
        
        label = Label(self.frame, text="Update sample interval for all nodes")
        label.grid(column=0, row=0, columnspan=2, sticky=W)
        
        label = Label(self.frame, text="Number of nodes selected:")
        label.grid(column=0, row=1, sticky=E)

        label = Label(self.frame, text=nodes)
        label.grid(column=1, row=1, sticky=E)

        label = Label(self.frame, text="New sample interval:")
        label.grid(column=0, row=2, sticky=E)
        
        self.sampleVar = StringVar()
        entry = Entry(self.frame, textvariable=self.sampleVar)
        entry.grid(column=1, row=2)
        
        button = Button(self.frame, text="Update", command=self.insertAll)
        button.grid(column=1, row=3)
        
        self.frame.grid(column=0, row=0)


    def insertAll(self):
        """ Update sample interval for all nodes in network.
        """
        interval = int(self.sampleVar.get())
        self.sampleVar.set("")
        
        for node in self.hub.node.offline:
            self.hub.node.offline[node] = interval
        
        self.hub.node.saveSettings()
        self.hub.node.initUI()



    def updateType(self, type):
        """ Update the sample interval for nodes with a specific sensor type attached
        """
        
        # find nodes with specified sensor type
        plexer = self.hub.node.plexer
        
        self.nodes = {}
        
        # plexer is a {node->list(multiplexer)}-map
        for node in plexer:
            plex = plexer[node]
            
            # plex is a list of multiplexers
            for p in plex:
                # each multiplexer is a tuble with multiplexer id and 8 sensor type channels
                for sensor in p[1:9]:
                    if sensor == type:
                        self.nodes[node] = 1
        
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
    


    def updateNode(self, node):
        """ Update the sample interval for single node.
        """
        
        self.nodes = { node: 1}
        
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
        
        interval = int(self.sampleVar.get())
        self.sampleVar.set("")
        
        for node in self.nodes:
            self.hub.node.offline[node] = interval
        
        self.hub.node.saveSettings()
        self.hub.node.initUI()


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



