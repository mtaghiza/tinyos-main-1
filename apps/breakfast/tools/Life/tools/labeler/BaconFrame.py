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

import time
import Tkinter
import tkMessageBox
from Tkinter import *

from tools.labeler.BreakfastError import *

class BaconFrame(Frame):

    def __init__(self, parent, handler, **args):
        Frame.__init__(self, parent, **args)
        
        self.parent = parent
        self.handler = handler
        self.barcodeSet = True

        self.initUI()
        self.disableUI()
        self.pack()

    def initUI(self):

        # row 1
        self.currentLabel = Label(self, text="Current")
        self.currentLabel.grid(column=2, row=1, columnspan=2)
        #         
        self.newLabel = Label(self, text="New")
        self.newLabel.grid(column=4, row=1)
        
        # row 2
        self.barcodeLabel = Label(self, text="Node ID:", width=11, anchor=E)
        self.barcodeLabel.grid(column=1, row=2)
                
        self.newBarcodeVar = StringVar()
        self.barcodeEntry = Entry(self, textvariable=self.newBarcodeVar, width=16)
        self.barcodeEntry.bind("<Return>", self.updateBarcodeKey)
        self.barcodeEntry.grid(column=4, row=2)
        
        self.barcodeVar = StringVar()
        self.barcodeVar.set("N/A")
        self.barcodeVarLabel = Label(self, textvariable=self.barcodeVar, width=16)
        self.barcodeVarLabel.grid(column=2, row=2, columnspan=2)

        # row 3
        self.mfrLabel = Label(self, text="Mfr ID:", width=11, anchor=E)
        self.mfrLabel.grid(column=1, row=3, sticky=E)
        
        self.mfrVar = StringVar()
        self.mfrVar.set("N/A")
        self.mfrVarLabel = Label(self, textvariable=self.mfrVar, width=16)
        self.mfrVarLabel.grid(column=2, row=3, columnspan=2)
         
        self.barcodeButton = Button(self, text="Save", command=self.updateBarcode, width=6)
        self.barcodeButton.grid(column=4, row=3)

        # row 4
        self.assignmentLabel = Label(self, text="Assignments:", width=11, anchor=E)
        self.assignmentLabel.grid(column=1, row=4)
        
        self.assignmentVar = StringVar()
        self.assignmentVar.set("")
        self.assignmentVarLabel = Label(self, textvar=self.assignmentVar)
        self.assignmentVarLabel.grid(column=2, row=4, columnspan=2)

        # row 5
        self.typeLabel = Label(self, text="Type")
        self.typeLabel.grid(column=2, row=5)
        self.idLabel = Label(self, text="ID")
        self.idLabel.grid(column=3, row=5)
        self.codeLabel = Label(self, text="Barcode")
        self.codeLabel.grid(column=4, row=5)

        # convert all the UI widgets to lists        
        self.stLabels   = []
        self.stTypeVars = []
        self.stIDVars   = []
        self.stTypeLabels = []
        self.stIDLabels   = []
        self.stNewIDVars  = []
        self.stNewIDEntries = []
        
        for i in range(0,3):
            self.stLabels.append(Label(self, text="Channel "+str(i), anchor=E))
            self.stTypeVars.append(StringVar())
            self.stIDVars.append(StringVar())
            self.stNewIDVars.append(StringVar())

            self.stTypeLabels.append(Label(self, textvariable=self.stTypeVars[i], anchor=E))            
            self.stIDLabels.append(Label(self, textvariable=self.stIDVars[i], anchor=E))
            self.stNewIDEntries.append(Entry(self, textvariable=self.stNewIDVars[i], width=6))                                           

            self.stTypeVars[i].set('N/A')
            self.stIDVars[i].set('N/A')
            
            self.stLabels[i].grid(column=1, row=i+6, sticky=E)
            self.stTypeLabels[i].grid(column=2, row=i+6)
            self.stIDLabels[i].grid(column=3, row=i+6)
            self.stNewIDEntries[i].grid(column=4, row=i+6)
#            self.stNewIDEntries[i].grid(column=4, row=i+6, columnspan=2)

        #   disable the ID entries for the internal sensors, those are hardwired
        for i in range(0,3):
            self.stNewIDEntries[i].config(state=DISABLED)

        self.reloadButton = Button(self, text="Reload", command=self.reconnect, width=6)
        self.reloadButton.grid(column=1, row=14, sticky=E)

        self.resetButton = Button(self, text="Reset all", command=self.reset, width=8)
        self.resetButton.grid(column=2, row=14, columnspan=2)
 
        self.assignButton = Button(self, text="Save", command=self.updateAssignments, width=6)
        self.assignButton.grid(column=4, row=14)

    def setUIstate(self,st,cur):
        #
        self.currentLabel.config(state=st)
        self.newLabel.config(state=st)
        self.barcodeLabel.config(state=st)
        self.mfrLabel.config(state=st)
        self.barcodeVarLabel.config(state=st)
        self.barcodeEntry.config(state=st)
        self.barcodeButton.config(state=st, cursor=cur)
        self.reloadButton.config(state=st, cursor=cur)
        self.mfrVarLabel.config(state=st)
            
        #
        self.assignmentLabel.config(state=st)
        self.typeLabel.config(state=st)
        self.idLabel.config(state=st)
        self.codeLabel.config(state=st)
        self.resetButton.config(state=st)
        self.assignButton.config(state=st)        
        #
        for i in range(0,3):
            self.stLabels[i].config(state=st)
            self.stIDLabels[i].config(state=st)
            self.stTypeLabels[i].config(state=st)
                
    def enableUI(self):
        self.setUIstate(st=NORMAL,cur="hand2")        

    def disableUI(self):
        # reset variables
        self.barcodeVar.set("Not available")
        self.mfrVar.set("Not available")
        #
        self.setUIstate(st=DISABLED,cur="")
            

    def connectSignal(self, connected):
        if connected:
            mfrStr = "Not available"
            
            try:
                mfrStr = self.handler.getMfrID()
            except Exception:
                self.mfrVar.set("Connection error")
                self.handler.programToaster()
            else:
                self.enableUI()
                self.mfrVar.set(mfrStr)
                self.redrawBarcode()
                self.handler.toastFrame.connectSignal(True)
                self.handler.adcFrame.connectSignal(True)
        else:
            self.disableUI()

    def reconnect(self):
        self.handler.busy()
        self.redrawBarcode()
        self.handler.notbusy()

    def sampleSignal(self, sampling):
#        return
         if sampling:
             self.disableUI()
         else:
             self.enableUI()

    def updateBarcodeKey(self, event):
        self.updateBarcode()

    def updateBarcode(self):        
        if self.barcodeSet:
            if not tkMessageBox.askokcancel("Warning", "Barcode already set. Do you wish to overwrite?", parent=self.parent):
                self.newBarcodeVar.set("")
                return
            
        self.handler.busy()
        try:
            self.handler.setBaconBarcode(self.newBarcodeVar.get())
        except ValueError:
            self.barcodeVar.set("Not an integer")
            self.barcodeVarLabel.config(fg="red")
            self.barcodeVarLabel.config(fg="red")
        except TypeError:
            self.barcodeVar.set("Incorrect type")
            self.barcodeVarLabel.config(fg="red")        
            self.barcodeVarLabel.config(fg="red")
        except:
            self.barcodeVar.set("Update failed")
            self.barcodeVarLabel.config(fg="red")
            self.barcodeVarLabel.config(fg="red")
        else:    
            self.handler.databaseBacon()
            self.newBarcodeVar.set("")
            self.redrawBarcode()
        self.handler.notbusy()
    
    def redrawBarcode(self):
        try:
            barcodeStr = self.handler.getBaconBarcode()
        except TagNotFoundError:
            self.barcodeVar.set("Barcode not set")
            self.barcodeEntry.focus_set()
            self.barcodeSet = False
        except:
            self.barcodeVar.set("Connection error")
            self.barcodeVarLabel.config(fg="red")
        else:
            self.barcodeVar.set(barcodeStr)
            self.barcodeVarLabel.config(fg="black")
            self.barcodeSet = True

    
    def reset(self):
        if not tkMessageBox.askokcancel("Warning", "Do you wish to completely reset device?", parent=self.parent):
            return
        self.handler.busy()
        if self.barcodeSet:
            self.handler.databaseRemoveSensors()
        self.handler.resetToast()
        self.reconnect()

    def updateAssignments(self):
        
        if not self.barcodeSet:    
            self.assignmentVar.set("Toast ID must be set")
            self.assignmentVarLabel.config(fg="red")
            return
        
        self.assignmentVar.set("")
        change = False
        duplicate = {}
        
        for i in range(0,4):
            newID = self.assignments[0][i]
            newType = self.assignments[1][i]
            
            setattr(self, "code", eval("self.stNewIDVars[%d].get()" % i))
            
            if self.code == "" and (newID is None or newType is None):
                # channel assignments must be contiguous
                break
            elif self.code != "":
                try:
                    tmp = int(self.code, 16)
                    newID = tmp & 0xFFFF
                    newType = (tmp >> 16) & 0xFF
                    
                    # sensor/type with non zero values are real assignments
                    # sensor/type with both zero values are channel resets
                    # sensor/type with either zero values are invalid
                    if bool(newID) ^ bool(newType):
                        raise
                except:
                    self.assignmentVar.set("Invalid input")
                    self.assignmentVarLabel.config(fg="red")
                    return
                
                if self.assignments[0][i] != newID:
                    self.assignments[0][i] = newID
                    change = True
                    
                if self.assignments[1][i] != newType:
                    self.assignments[1][i] = newType
                    change = True
                
            if newID and newType:
                print (str(newID)+str(newType))
                if (str(newID)+str(newType)) in duplicate:
                    self.assignmentVar.set("Duplicate entry")
                    self.assignmentVarLabel.config(fg="red")
                    return
                else:
                    duplicate[(str(newID)+str(newType))] = 1
            
            
        if change:
            self.handler.busy()
            print self.assignments
            try:
                # write to toast TLV area
                self.handler.setAssignments(self.assignments)
            except OutOfSpaceError:
                self.assignmentVar.set("Out of memory")
            except UnexpectedResponseError:
                self.assignmentVar.set("Update Failed")
            else:
                for i in range(0,3):
                    self.stNewIDVars[i].set('')
                self.redrawAssignments()
                
                # insert into database
                self.handler.databaseSensors()
            self.handler.notbusy()
