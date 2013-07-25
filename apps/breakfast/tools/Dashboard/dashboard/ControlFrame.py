import Tkinter
from Tkinter import *


class ControlFrame(Frame):

    DEFAULT_STRING = "N/A"

    def __init__(self, parent, hub, **args):
        Frame.__init__(self, parent, **args)
        
        self.hub = hub
        
        self.initUI()


    def initUI(self):
        
        self.allButton = Button(self, text="Select All", command=self.selectAll)
        self.allButton.grid(column=0, row=0)
        
        self.typeVar = StringVar()        
        self.typeVar.set(self.DEFAULT_STRING)
        self.typeOption = OptionMenu(self, self.typeVar, [self.DEFAULT_STRING])
        self.typeOption.config(state=DISABLED)
        #self.typeOption.config(width=25)
        self.typeOption.grid(column=1, row=0)
        
        self.typeButton = Button(self, text="Select Type", command=self.selectType)
        self.typeButton.grid(column=2, row=0)
        
        self.refreshButton = Button(self, text="Refresh", command=self.refresh)
        self.refreshButton.grid(column=3, row=0)

    def updateTypes(self, types):
        menu = self.typeOption["menu"]
        menu.delete(0, "end")
        
        # populate menu
        for key in sorted(types.keys()):
            if key != 0:
                menu.add_command(label=key, command=Tkinter._setit(self.typeVar, key))
                if self.typeVar.get() == self.DEFAULT_STRING:
                    self.typeVar.set(key)
                    self.typeOption.config(state=NORMAL)

    
    def selectAll(self):
        """ Select all visible nodes in network so the sample interval can
            be changed simultaneously.
        """
        
        self.hub.display.updateAll()


    def selectType(self):
        """ Select all nodes with the specified sensor type attached.
        """
        
        self.hub.display.updateType(int(self.typeVar.get()))


    def refresh(self):
        self.hub.node.initUI()
    
    
    