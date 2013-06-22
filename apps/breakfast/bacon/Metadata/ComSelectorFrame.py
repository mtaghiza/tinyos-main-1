
import Tkinter
from Tkinter import *
from serial.tools.list_ports import *
#from ttk import *
from Chef import Chef
import ttk

class ComSelectorFrame(Frame):

    comDict = {}
    DEFAULT_STRING = "<no device detected>"

    def __init__(self, parent, handler, **args):
        Frame.__init__(self, parent, **args)
        
        self.handler = handler
        
        # 
        self.connectVar = BooleanVar()
        self.connectVar.trace("w", self.connectionChanged)
        
        # 
        self.programVar = BooleanVar()
        self.programVar.trace("w", self.programDone)
        
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
        self.comOption.grid(column=1,row=1)
        
        # connect button. disabled when no device detected and when already connected
        # turns green when connected otherwise gray
        self.connectButton = Button(self, text="Connect", background="gray", state=DISABLED, command=Tkinter._setit(self.connectVar, True))
        self.connectButton.grid(column=2,row=1)
        
        # disconnect button. disabled and red when not connected otherwise gray.
        self.disconnectButton = Button(self, text="Disonnected", bg="red", state=DISABLED, command=Tkinter._setit(self.connectVar, False))
        self.disconnectButton.grid(column=3,row=1)
        
        # program buttons
        self.toasterButton = Button(self, text="Program Toaster", bg="gray", state=DISABLED, command=self.programtoaster)
        self.toasterButton.grid(column=5, row=1)

        self.leafButton = Button(self, text="Program Leaf", bg="gray", state=DISABLED, command=self.programLeaf)
        self.leafButton.grid(column=7, row=1)
        
        self.routerButton = Button(self, text="Program Router", bg="gray", state=DISABLED, command=self.programRouter)
        self.routerButton.grid(column=8, row=1)

        self.basestationButton = Button(self, text="Program Basestation", bg="gray", state=DISABLED, command=self.programBasestation)
        self.basestationButton.grid(column=9, row=1)
        
        # progress bar
        self.progressVar = IntVar()
        self.progressVar.set(0)
        self.progressBar = ttk.Progressbar(self, orient='horizontal', variable=self.progressVar, length=100, mode='determinate')
        self.progressBar.grid(column=10, row=1)
        
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
        if self.connectVar.get() and self.comVar.get() not in newDict:
            self.connectVar.set(False)
        
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
                self.comOption.config(state=NORMAL)
                self.connectButton.config(state=NORMAL)
                self.toasterButton.config(state=NORMAL)
                self.leafButton.config(state=NORMAL)
                self.routerButton.config(state=NORMAL)
                self.basestationButton.config(state=NORMAL)
            else:
                # no devices found. disable menu and all buttons.
                menu.add_command(label=self.DEFAULT_STRING, command=lambda value=string: self.comVar.set(self.DEFAULT_STRING))
                self.comVar.set(self.DEFAULT_STRING)
                self.comOption.config(state=DISABLED)
                self.connectButton.config(bg="gray", state=DISABLED)
                self.disconnectButton.config(bg="red", state=DISABLED)
                self.toasterButton.config(state=DISABLED)
                self.leafButton.config(state=DISABLED)
                self.routerButton.config(state=DISABLED)
                self.basestationButton.config(state=DISABLED)
            
            # update
            self.comDict = newDict
            
        # run detection again after 1000 ms
        self.comOption.after(1000, self.deviceDetection)


    def connectionChanged(self, name, index, mode):
        """ Event handler for changing connection status.
        """        
        if self.connectVar.get():
            
            self.handler.connect(self.comDict[self.comVar.get()], self.connectVar)
            
            # enable/disable buttons and change color
            self.comOption.config(state=DISABLED)
            self.connectButton.config(text="Connected", bg="green", state=DISABLED)
            self.disconnectButton.config(text="Disconnect", bg="gray", state=NORMAL)
            self.toasterButton.config(state=DISABLED)
            self.leafButton.config(state=DISABLED)
            self.routerButton.config(state=DISABLED)
            self.basestationButton.config(state=DISABLED)
        else:
            
            self.handler.disconnect(self.connectVar)
            
            # enable/disable buttons and change color
            self.comOption.config(state=NORMAL)
            self.connectButton.config(text="Connect", bg="gray", state=NORMAL)
            self.disconnectButton.config(text="Disconnected", bg="red", state=DISABLED)
            self.toasterButton.config(state=NORMAL)
            self.leafButton.config(state=NORMAL)
            self.routerButton.config(state=NORMAL)
            self.basestationButton.config(state=NORMAL)

    def disableUI(self):
        self.programming = True
        self.comOption.config(state=DISABLED)
        self.connectButton.config(state=DISABLED)
        self.toasterButton.config(state=DISABLED)
        self.leafButton.config(state=DISABLED)
        self.routerButton.config(state=DISABLED)
        self.basestationButton.config(state=DISABLED)

    def enableUI(self):
        self.programming = False
        self.comOption.config(state=NORMAL)
        self.connectButton.config(state=NORMAL)
        self.toasterButton.config(state=NORMAL)
        self.leafButton.config(state=NORMAL)
        self.routerButton.config(state=NORMAL)
        self.basestationButton.config(state=NORMAL)

    def programtoaster(self):
        self.disableUI()
        self.handler.program("toaster", self.comDict[self.comVar.get()], self.programDone)

        TOASTER_SIZE = 19864
        self.programSize = TOASTER_SIZE
        self.programProgress()
    
    def programLeaf(self):
        self.disableUI()
        self.handler.program("leaf", self.comDict[self.comVar.get()], self.programDone)

    def programRouter(self):
        self.disableUI()
        self.handler.program("router", self.comDict[self.comVar.get()], self.programDone)

    def programBasestation(self):
        self.disableUI()
        self.handler.program("basestation", self.comDict[self.comVar.get()], self.programDone)

    def programProgress(self):
        progress = self.handler.programProgress() * 100.0 / self.programSize
        
        if progress > self.progressVar.get():
            self.progressVar.set(progress)

        if self.programming:
            self.progressBar.after(200, self.programProgress)
        else:
            self.progressVar.set(0)

    def programDone(self, status):
        self.enableUI()
        print status


if __name__ == '__main__':
    root = Tk()
    
    chef = Chef()    
    comFrame = ComSelectorFrame(root, chef)
    
    root.mainloop()