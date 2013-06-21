import Tkinter
from Tkinter import *
from serial.tools.list_ports import *

class ComSelectorFrame(Frame):

    comDict = {}
    connected = False
    DEFAULT_STRING = "<no device detected>"

    def __init__(self, *args):
        Frame.__init__(self, *args)
        
        self.initUI()
        self.pack()

    def initUI(self):
        """Create an option menu, a connect button, and a disconnect button inside a frame
        """
        
        # option menu. menu is populated by the deviceDetection function
        self.comVar = StringVar()        
        self.comOption = OptionMenu(self, self.comVar, [self.DEFAULT_STRING])
        self.comOption.grid(column=1,row=1)
        
        # connect button. disabled when no device detected and when already connected
        # turns green when connected otherwise gray
        self.connectButton = Button(self, text="Connect", bg="gray", state=DISABLED, command=self.connect)
        self.connectButton.grid(column=2,row=1)
        
        # disconnect button. disabled and red when not connected otherwise gray.
        self.disconnectButton = Button(self, text="Disonnected", bg="red", state=DISABLED, command=self.disconnect)
        self.disconnectButton.grid(column=3,row=1)
        
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
                
                # enable menu and connect button
                self.comOption.config(state=NORMAL)
                self.connectButton.config(state=NORMAL)
            else:
                # no devices found. disable menu and all buttons.
                menu.add_command(label=self.DEFAULT_STRING, command=lambda value=string: self.comVar.set(self.DEFAULT_STRING))
                self.comVar.set(self.DEFAULT_STRING)
                self.comOption.config(state=DISABLED)
                self.connectButton.config(bg="gray", state=DISABLED)
                self.disconnectButton.config(bg="red", state=DISABLED)
            
            # update
            self.comDict = newDict
            
        # run detection again after 1000 ms
        self.comOption.after(1000, self.deviceDetection)


    def connect(self):
        """ Event handler for the connect button.
        """
        if not self.connected:
            self.connected = True
            
            print self.comDict[self.comVar.get()]
            
            # enable/disable buttons and change color
            self.comOption.config(state=DISABLED)
            self.connectButton.config(text="Connected", bg="green", state=DISABLED)
            self.disconnectButton.config(text="Disconnect", bg="gray", state=NORMAL)

    def disconnect(self):
        """ Event handler for the disconnect button.
        """
        if self.connected:
            self.connected = False
            
            # enable/disable buttons and change color
            self.comOption.config(state=NORMAL)
            self.connectButton.config(text="Connect", bg="gray", state=NORMAL)
            self.disconnectButton.config(text="Disconnected", bg="red", state=DISABLED)



if __name__ == '__main__':
    root = Tk()
    
    comFrame = ComSelectorFrame(root)
    
    root.mainloop()