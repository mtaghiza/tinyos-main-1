#!/usr/bin/env python

import Tkinter
import tkMessageBox
from Tkinter import *

from tools.serial.tools.list_ports import *
from tools.labeler.Handler import Handler
import tools.labeler.ttk as ttk

class MenuFrame(Frame):

    BASESTATION_SIZE = 3326
    ROUTER_SIZE = 3326
    LEAF_SIZE = 3326
    TOASTER_SIZE = 20136

    comDict = {}
    DEFAULT_STRING = "<no device detected>"

    def __init__(self, parent, handler, **args):
        Frame.__init__(self, parent, **args)
        
        # parent frame - for centering pop-up boxes
        self.parent = parent
        
        # handler for UI actions
        self.handler = handler
        
        # connection status
        self.connected = False
        
        # variable to track programming status 
        self.programVar = BooleanVar()
        self.programVar.trace("w", self.programDone)
        
        #
        self.basestation_file = os.path.join('tools', 'firmware', 'basestation.ihex')
        self.leaf_file = os.path.join('tools', 'firmware', 'leaf.ihex')
        self.router_file = os.path.join('tools', 'firmware', 'router.ihex')
        self.toaster_file = os.path.join('tools', 'firmware', 'toaster.ihex')
        
        
        
        self.initUI()
        self.pack()

    def initUI(self):
        """Create an option menu, a connect button, and a disconnect button inside a frame
        """
        
        # option menu. menu is populated by the deviceDetection function
        self.comVar = StringVar()        
        self.comVar.set(self.DEFAULT_STRING)
        self.comOption = OptionMenu(self, self.comVar, [self.DEFAULT_STRING])
        self.comOption.config(state=DISABLED)
        self.comOption.config(width=25)
        self.comOption.grid(column=1,row=1)
        
        # connect button. disabled when no device detected and when already connected
        # turns green when connected otherwise gray
        self.connectButton = Button(self, width=12, text="Connect", background="gray", state=DISABLED, command=self.connect)
        self.connectButton.grid(column=2,row=1)
        
        # disconnect button. disabled and red when not connected otherwise gray.
        self.disconnectButton = Button(self, width=12, text="Disconnected", bg="red", state=DISABLED, command=self.disconnect)
        self.disconnectButton.grid(column=3,row=1)
        
        # space
        self.s3Frame = Frame(self, width=10)
        self.s3Frame.grid_propagate(False)
        self.s3Frame.grid(column=4, row=1)
    
        # export CSV
        self.exportButton = Button(self, text="Export Database", bg="gray", state=DISABLED, command=self.exportCSV)
        self.exportButton.grid(column=5, row=1)

        # space
        self.s1Frame = Frame(self, width=10)
        self.s1Frame.grid_propagate(False)
        self.s1Frame.grid(column=6, row=1)
        
        # program buttons
        self.toasterButton = Button(self, text="Program Labeler", bg="gray", state=DISABLED, command=self.programToaster)
        self.toasterButton.grid(column=7, row=1)

        self.leafButton = Button(self, text="Program Node", bg="gray", state=DISABLED, command=self.programLeaf)
        self.leafButton.grid(column=8, row=1)
        
        self.routerButton = Button(self, text="Program Router", bg="gray", state=DISABLED, command=self.programRouter)
        self.routerButton.grid(column=9, row=1)

        self.basestationButton = Button(self, text="Program Basestation", bg="gray", state=DISABLED, command=self.programBasestation)
        self.basestationButton.grid(column=10, row=1)

        # space
        self.s2Frame = Frame(self, width=10)
        self.s2Frame.grid_propagate(False)
        self.s2Frame.grid(column=11, row=1)
        
        # progress bar
        self.progressVar = IntVar()
        self.progressVar.set(0)
        self.progressBar = ttk.Progressbar(self, orient='horizontal', variable=self.progressVar, length=100, mode='determinate')
        self.progressBar.grid(column=12, row=1)

#        # space
#        self.s3Frame = Frame(self, width=10)
#        self.s3Frame.grid_propagate(False)
#        self.s3Frame.grid(column=13, row=1)
#
#        self.updateButton = Button(self, text="Update", bg="gray", state=DISABLED, width=10, command=self.programBasestation)
#        self.updateButton.grid(column=14, row=1)
        
        # detect devices. this function calls itself every second.
        self.deviceDetection()


    def deviceDetection(self):
        """ Detect serial devices by using the built-in comports command in pyserial.
        """
        # make dictionary with (description, comport)
        newDict = {}
        ports = sorted(comports())
        for port, desc, hwid in ports:
            newDict[desc] = port
        
        # call disconnect function if the current device disappears
        if self.connected and self.comVar.get() not in newDict:
            self.disconnect()
        
        # update menu when not currently connected
        if newDict != self.comDict:
            
            # reset menu
            menu = self.comOption["menu"]
            menu.delete(0, "end")
            
            # keep current selection
            oldIndex = self.comVar.get()
            
            # if devices were found
            if newDict:
                
                # populate menu
                for key in sorted(newDict.keys()):    
                    menu.add_command(label=key, command=Tkinter._setit(self.comVar, key))
                    #lambda: self.comVar.set(key))
                
                # choose first port if no port was previously selected
                if oldIndex not in newDict:
                    self.comVar.set(ports[0][1])
                
                # enable menu and connect/programming buttons
                self.enableUI()
                #self.comOption.config(state=NORMAL)
                #self.connectButton.config(state=NORMAL)
                #self.toasterButton.config(state=NORMAL)
                #self.leafButton.config(state=NORMAL)
                #self.routerButton.config(state=NORMAL)
                #self.basestationButton.config(state=NORMAL)
            else:
                # no devices found. disable menu and all buttons.
                menu.add_command(label=self.DEFAULT_STRING, command=Tkinter._setit(self.comVar, self.DEFAULT_STRING))
                #menu.add_command(label=self.DEFAULT_STRING, command=lambda value=string: self.comVar.set(self.DEFAULT_STRING))
                self.comVar.set(self.DEFAULT_STRING)
                #self.comOption.config(state=DISABLED)
                #self.toasterButton.config(state=DISABLED)
                #self.leafButton.config(state=DISABLED)
                #self.routerButton.config(state=DISABLED)
                #self.basestationButton.config(state=DISABLED)
                self.disableUI()
                self.connectButton.config(bg="gray", state=DISABLED, cursor="")
                self.disconnectButton.config(bg="red", state=DISABLED, cursor="")
            
            # update
            self.comDict = newDict
            
        # run detection again after 1000 ms
        self.comOption.after(1000, self.deviceDetection)


    def connect(self):
        """ Event handler for changing connection status.
        """        
        self.handler.busy()
        self.connected = True
        
        # enable/disable buttons and change color
        #self.comOption.config(state=DISABLED)
        #self.toasterButton.config(state=DISABLED)
        #self.leafButton.config(state=DISABLED)
        #self.routerButton.config(state=DISABLED)
        #self.basestationButton.config(state=DISABLED)
        self.disableUI()
        self.connectButton.config(text="Connected", bg="green", state=DISABLED, cursor="")
        self.disconnectButton.config(text="Disconnect", bg="gray", state=NORMAL, cursor="hand2")
        
        self.handler.connect(self.comDict[self.comVar.get()])

    def disconnect(self):
        """ Event handler for changing connection status.
        """        
        self.handler.busy()
        self.connected = False
        
        # enable/disable buttons and change color
        #self.comOption.config(state=NORMAL)
        #self.toasterButton.config(state=NORMAL)
        #self.leafButton.config(state=NORMAL)
        #self.routerButton.config(state=NORMAL)
        #self.basestationButton.config(state=NORMAL)
        self.enableUI()
        self.connectButton.config(text="Connect", bg="gray", state=NORMAL, cursor="hand2")
        self.disconnectButton.config(text="Disconnected", bg="red", state=DISABLED, cursor="")
        
        self.handler.disconnect()
        self.handler.notbusy()


    def disableUI(self):
        self.comOption.config(state=DISABLED, cursor="")
        self.connectButton.config(state=DISABLED, cursor="")
        self.exportButton.config(state=DISABLED, cursor="")
        self.toasterButton.config(state=DISABLED, cursor="")
        self.leafButton.config(state=DISABLED, cursor="")
        self.routerButton.config(state=DISABLED, cursor="")
        self.basestationButton.config(state=DISABLED, cursor="")

    def enableUI(self):
        self.comOption.config(state=NORMAL, cursor="hand2")
        self.connectButton.config(state=NORMAL, cursor="hand2")
        self.disconnectButton.config(bg="red", state=DISABLED, cursor="")
        self.exportButton.config(state=NORMAL, cursor="hand2")
        self.toasterButton.config(state=NORMAL, cursor="hand2")
        self.leafButton.config(state=NORMAL, cursor="hand2")
        self.routerButton.config(state=NORMAL, cursor="hand2")
        self.basestationButton.config(state=NORMAL, cursor="hand2")

    def programToaster(self):
        self.handler.busy()
        self.disableUI()

        self.progressVar.set(0)
        self.programming = True
        self.programSize = self.TOASTER_SIZE
        self.handler.program(self.toaster_file, self.comDict[self.comVar.get()], self.programDone)
        self.programProgress()
    
    def programLeaf(self):
        self.handler.busy()
        self.disableUI()

        self.progressVar.set(0)
        self.programming = True
        self.programSize = self.LEAF_SIZE
        self.handler.program(self.leaf_file, self.comDict[self.comVar.get()], self.programDone)
        self.programProgress()

    def programRouter(self):
        self.handler.busy()
        self.disableUI()

        self.progressVar.set(0)
        self.programming = True
        self.programSize = self.ROUTER_SIZE
        self.handler.program(self.router_file, self.comDict[self.comVar.get()], self.programDone)
        self.programProgress()

    def programBasestation(self):
        self.handler.busy()
        self.disableUI()

        self.progressVar.set(0)
        self.programming = True
        self.programSize = self.BASESTATION_SIZE
        self.handler.program(self.basestation_file, self.comDict[self.comVar.get()], self.programDone)
        self.programProgress()

    def programProgress(self):
        progress = self.handler.programProgress() * 100.0 / self.programSize
        
        if progress > self.progressVar.get():
            self.progressVar.set(progress)

        if self.programming:
            self.progressBar.after(200, self.programProgress)
        else:
            # reset progress bar
            self.progressVar.set(0)                        
            self.enableUI()
            self.handler.notbusy()

            if self.programmingStatus:
                tkMessageBox.showinfo("Labeler", "Programming done", parent=self.parent)
            else:
                tkMessageBox.showerror("Error", "Programming failed", parent=self.parent)

    def programDone(self, status):
        self.programming = False
        self.programmingStatus = status


    def exportCSV(self):
        try:
            self.handler.exportCSV()
        except:
            tkMessageBox.showerror("Error", "CSV export failed", parent=self.parent)
        else:
            tkMessageBox.showinfo("Labeler", "CSV export done", parent=self.parent)

if __name__ == '__main__':
    root = Tk()
    
    handler = Handler()    
    menuFrame = MenuFrame(root, handler)
    
    root.mainloop()