#!/usr/bin/env python

# Copyright (c) 2014 Johns Hopkins University
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# - Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
# - Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the
#   distribution.
# - Neither the name of the copyright holders nor the names of
#   its contributors may be used to endorse or promote products derived
#   from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
# THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.


import Tkinter
import subprocess
import tkMessageBox
import webbrowser
import os
from Tkinter import *

from tools.serial.tools.list_ports import *
from tools.labeler.Handler import Handler
from tools.labeler.GraphFrame import GraphFrame
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
        
        #        
        self.initUI()
        self.pack()

    def initUI(self):
        """Create an option menu, a connect button, and a disconnect button inside a frame
        """
        
        # column 3, space
        self.h0 = Frame(self, width=3)
        self.h0.grid_propagate(False)
        self.h0.grid(column=0, row=1)

        # column 1, connect button
        # disabled when no device detected
        # turns green when connected otherwise gray
        self.connectButton = Button(self, width=12, text="Connect", bg="gray", state=DISABLED, command=self.connect)
        self.connectButton.grid(column=1,row=1)

        # column 2, option menu for COM port
        # populated by the deviceDetection function
        self.comVar = StringVar()        
        self.comVar.set(self.DEFAULT_STRING)
        self.comOption = OptionMenu(self, self.comVar, [self.DEFAULT_STRING])
        self.comOption.config(state=DISABLED)
        self.comOption.config(width=26)
        self.comOption.grid(column=2,row=1)
        
                
        # column 3, space
        self.h1 = Frame(self, width=5)
        self.h1.grid_propagate(False)
        self.h1.grid(column=3, row=1)
        
    
        # column 4, export CSV
        self.exportButton = Button(self, text="Export Database", bg="gray", state=DISABLED, width=16, command=self.exportCSV)
        self.exportButton.grid(column=4, row=1)

        # column 5, space
        self.h2 = Frame(self, width=5)
        self.h2.grid_propagate(False)
        self.h2.grid(column=5, row=1)
        
        # program buttons
        
        # column 6, Program Node
        self.leafButton = Button(self, text="Program Node", bg="gray", state=DISABLED, width=16, command=self.programLeaf)
        self.leafButton.grid(column=6, row=1)
        
        # column 7, Program Router
        self.routerButton = Button(self, text="Program Router", bg="gray", state=DISABLED, width=16, command=self.programRouter)
        self.routerButton.grid(column=7, row=1)

        # column 8, Program Basestation
        self.basestationButton = Button(self, text="Program Basestation", bg="gray", state=DISABLED, width=18, command=self.programBasestation)
        self.basestationButton.grid(column=8, row=1)

        # column 9, space
        self.h3 = Frame(self, width=5)
        self.h3.grid_propagate(False)
        self.h3.grid(column=9, row=1)
        
        # column 10, progress bar
        self.progressVar = IntVar()
        self.progressVar.set(0)
        self.progressBar = ttk.Progressbar(self, orient='horizontal', variable=self.progressVar, length=104, mode='determinate')
        self.progressBar.grid(column=10, row=1)

        # column 11, space
        self.h4 = Frame(self, width=5)
        self.h4.grid_propagate(False)
        self.h4.grid(column=11, row=1)

        # column 14, Help
        self.helpButton = Button(self, text="Help", bg="gray", state=NORMAL, width=15, command=self.show_help)
        self.helpButton.grid(column=14, row=1)
        self.helpButton.config(state=NORMAL, cursor="hand2")
                
        # send message
        self.handler.debugMsg("No USB device detected, plase insert one")
        
        # detect devices. this function calls itself every second.
        self.deviceDetection()

    def donothing(self):
            return

    def deviceDetection(self):
        """ Detect serial devices by using the built-in comports command in pyserial.
        """
        # make dictionary with (description, comport)
        newDict = {}
        ports = sorted(comports())
        for port, desc, hwid in ports:
            newDict[desc] = port
        
        
#         if self.connected:
#             self.handler.debugMsg("USB device detected, press any menu button to start")

        # call disconnect function if the current device disappears
        if self.connected and self.comVar.get() not in newDict:
            self.handler.debugMsg("No USB device detected, please connect one...")
            self.disconnect()

        # update menu when not currently connected
        if newDict != self.comDict:
            
            self.handler.debugMsg("No USB device detected, please connect one...")

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
                self.handler.debugMsg("USB device detected, press any menu button to start")
                
            else:
                # no devices found. disable menu and all buttons.
                menu.add_command(label=self.DEFAULT_STRING, command=Tkinter._setit(self.comVar, self.DEFAULT_STRING))
                #menu.add_command(label=self.DEFAULT_STRING, command=lambda value=string: self.comVar.set(self.DEFAULT_STRING))
                self.comVar.set(self.DEFAULT_STRING)
                self.disableUI()
                self.connectButton.config(bg="gray", state=DISABLED, cursor="")
                self.handler.debugMsg("No USB device detected, please connect one...")
                
            # update
            self.comDict = newDict
            
        # run detection again after 1000 ms
        self.comOption.after(1000, self.deviceDetection)


    def connect(self):
        """ Event handler for changing connection status.
        """        
        self.handler.debugMsg("Connecting to Bacon...")
        self.handler.busy()
        self.connected = True
        
        self.disableUI()
        self.connectButton.config(text="Disconnect", bg="green", command=self.disconnect, state=NORMAL, cursor="hand2") 
        self.helpButton.config(state=NORMAL, cursor="hand2")
        self.handler.connect(self.comDict[self.comVar.get()])

    def disconnect(self):
        """ Event handler for changing connection status.
        """        
        self.handler.busy()
        self.connected = False
        
        self.enableUI()
        self.connectButton.config(text="Connect", bg="gray", state=NORMAL, cursor="hand2", command=self.connect)
        self.handler.disconnect()
        self.handler.notbusy()


    def disableUI(self):
        self.comOption.config(state=DISABLED, cursor="")
        self.connectButton.config(state=DISABLED, cursor="")
        self.leafButton.config(state=DISABLED, cursor="")
        self.routerButton.config(state=DISABLED, cursor="")
        self.basestationButton.config(state=DISABLED, cursor="")
        self.exportButton.config(state=DISABLED, cursor="")
        self.helpButton.config(state=DISABLED,cursor="")

    def enableUI(self):
        self.comOption.config(state=NORMAL, cursor="hand2")
        self.connectButton.config(state=NORMAL, cursor="hand2")
        self.leafButton.config(state=NORMAL, cursor="hand2")
        self.routerButton.config(state=NORMAL, cursor="hand2")
        self.basestationButton.config(state=NORMAL, cursor="hand2")
        self.exportButton.config(state=NORMAL, cursor="hand2")
        self.helpButton.config(state=NORMAL, cursor="hand2")

    
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

    def show_help(self):
        webbrowser.open("file://"+os.path.realpath("LabelerGuide.pdf"))
#         self.top = Toplevel()
#         self.top.title("Labeler Help")
#         self.helpWindow = Text(self.top)
# 
#         self.helpY = Scrollbar(self.top,orient=VERTICAL)
#         self.helpY.config(command=self.helpWindow.yview)
#         self.helpY.pack(side=RIGHT,fill=Y)
# 
#         self.helpX = Scrollbar(self.top, orient=HORIZONTAL)
#         self.helpX.config(command=self.helpWindow.xview)
#         self.helpX.pack(side=BOTTOM,fill=X)
#         
#         helpfile = file("labeler.help.txt")
#         helptext = helpfile.read()
#         helpfile.close()
# 
#         self.helpWindow.insert(0.0,helptext)
#         # insert hyperlink
#         self.helpWindow.insert()
#         self.helpWindow.config(state=DISABLED, wrap=NONE, xscrollcommand=self.helpX.set, yscrollcommand=self.helpY.set)
#         self.helpWindow.pack(side=TOP, expand=True,fill=BOTH)
        

if __name__ == '__main__':
    root = Tk()
    
    handler = Handler()    
    menuFrame = MenuFrame(root, handler)
    
    root.mainloop()
