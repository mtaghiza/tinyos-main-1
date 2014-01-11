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
import tkMessageBox

from copy import deepcopy
from Tkinter import *
from tools.labeler.BreakfastError import *
from tools.labeler.Toast import Toast


class ToastFrame(Frame):
    
    TYPE_TOAST = 0x05
    TYPE_MINITOAST = 0x06
    
    EMPTY_ASSIGNMENTS = [[None,None,None,None,None,None,None,None],[None,None,None,None,None,None,None,None]]
    
    def __init__(self, parent, handler, **args):
        Frame.__init__(self, parent, **args)
        
        self.parent = parent
        self.handler = handler
        
        self.assignments = deepcopy(self.EMPTY_ASSIGNMENTS)
        self.sampling = False
        
        self.toastType = self.TYPE_TOAST
        self.barcodeArray = []
        
        self.barcodeSet = True
        
        self.initUI()
        self.disableBarcodeUI()
        self.disableAssignmentUI()
        self.pack()

    def initUI(self):
        self.initToastID()
        self.initToastAssignments()

    def initToastID(self):
        #row 1        
        self.currentLabel = Label(self, text="Current")
        self.currentLabel.grid(column=2, row=1, columnspan=2)

        self.newLabel = Label(self, text="New")
        self.newLabel.grid(column=4, row=1)

        #row 2
        self.barcodeLabel = Label(self, text="MUX ID:", width=11, anchor=E)
        self.barcodeLabel.grid(column=1, row=2)

        self.barcodeVar = StringVar()
        self.barcodeVar.set("Not available")
        self.barcodeVarLabel = Label(self, textvar=self.barcodeVar, width=16)
        self.barcodeVarLabel.grid(column=2, row=2, columnspan=2)

        self.newBarcodeVar = StringVar()
        self.newBarcodeEntry = Entry(self, textvar=self.newBarcodeVar, width=16)
        self.newBarcodeEntry.bind("<Return>", self.updateBarcodeKey)
        self.newBarcodeEntry.grid(column=4, row=2)

        # row 3
        self.dcoLabel = Label(self, text="DCO:", width=11, anchor=E)
        self.dcoLabel.grid(column=1, row=3)

        self.dcoVar = StringVar()
        self.dcoVar.set("Not available")        
        self.dcoVarLabel = Label(self, textvar=self.dcoVar)
        self.dcoVarLabel.grid(column=2, row=3, columnspan=2)        

#         self.reloadButton = Button(self, text="Reload", command=self.reconnect, width=6)
#         self.reloadButton.grid(column=4, row=3) 
        self.newBarcodeButton = Button(self, text="Save", command=self.updateBarcode, width=6)
        self.newBarcodeButton.grid(column=4, row=3) 

    def initToastAssignments(self):
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
        
        for i in range(0,8):
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
            self.stNewIDEntries[i].grid(column=4, row=i+6, columnspan=2)
            
#            self.stNewIDEntries[i].bind('<Return>', self.changeFocus)

        self.reloadButton = Button(self, text="Reload", command=self.reconnect, width=8)
        self.reloadButton.grid(column=1, row=14, sticky=E) 

        self.resetButton = Button(self, text="Reset all", command=self.reset, width=8)
        self.resetButton.grid(column=2, row=14, columnspan=2)
        
        self.assignButton = Button(self, text="Save", command=self.updateAssignments, width=6)
        self.assignButton.grid(column=4, row=14)

    def enableUI(self):
        self.enableBarcodeUI()
        self.enableAssignmentUI()

    def disableUI(self):
        self.disableBarcodeUI()
        self.disableAssignmentUI()

    def setBarcodeUIstate(self, st, cur):
        self.currentLabel.config(state=st)
        self.newLabel.config(state=st)
        self.dcoLabel.config(state=st)
        self.dcoVarLabel.config(state=st)
        self.reloadButton.config(state=st, cursor=cur)
        self.barcodeLabel.config(state=st)
        self.barcodeVarLabel.config(state=st)
        self.newBarcodeEntry.config(state=st)
        self.newBarcodeButton.config(state=st, cursor=cur)

    def enableBarcodeUI(self):
        self.setBarcodeUIstate(st=NORMAL,cur="hand2")        

    def disableBarcodeUI(self):
        # reset variables
        self.barcodeVar.set("Not available")
        self.dcoVar.set("Not available")        
        self.setBarcodeUIstate(st=DISABLED,cur="")
                
    def setAssignmentUIstate(self,st,cur):
        #
        self.assignmentLabel.config(state=st)
        self.assignmentVarLabel.config(state=st)
        #
        self.assignButton.config(state=st, cursor=cur)
        self.resetButton.config(state=st, cursor=cur)
        #
        # assignment frame
        self.typeLabel.config(state=st)
        self.idLabel.config(state=st)
        self.codeLabel.config(state=st)
        #

        if self.toastType == self.TYPE_TOAST or self.toastType==0:                        
            for i in range(0,8):
                self.stLabels[i].config(state=st) 
                self.stTypeLabels[i].config(state=st)
                self.stIDLabels[i].config(state=st)
                self.stNewIDEntries[i].config(state=st)
            
        if self.toastType == self.TYPE_MINITOAST:                
            qst = DISABLED
            for i in range(0,8):
                self.stLabels[i].config(state=qst) 
                self.stTypeLabels[i].config(state=qst)
                self.stIDLabels[i].config(state=qst)
                self.stNewIDEntries[i].config(state=qst)

            # only 3 channels active, but only one barcode
            for i in range(0,3):
                self.stLabels[i].config(state=st)
                self.stTypeLabels[i].config(state=st)      
                self.stIDLabels[i].config(state=st)
                
            # the only confgurable sensor on the miniToast    
            self.stNewIDEntries[2].config(state=st)
            

    def enableAssignmentUI(self):
        #
        self.setAssignmentUIstate(st=NORMAL,cur="hand2")

#<alex> What is this for ?????
##            self.sensor2Label.config(state=NORMAL)
##            self.sensor2TypeLabel.config(state=NORMAL)
##            self.sensor2IDLabel.config(state=NORMAL)
##            self.sensor2newIDEntry.config(state=NORMAL)
##            
##            # bind enter key to sensor 2
##            self.sensor7newIDEntry.unbind('<Return>')
##            self.sensor2newIDEntry.bind('<Return>', self.updateAssignmentsKey)
            

    def disableAssignmentUI(self):
        # reset variables
        self.assignmentVar.set("")
        self.assignments = deepcopy(self.EMPTY_ASSIGNMENTS)
    
        for i in range(0,8):
            self.stTypeVars[i].set('N/A')
            self.stIDVars[i].set('N/A')
            self.stNewIDVars[i].set('')
            
        self.setAssignmentUIstate(st=DISABLED,cur="")
            

    def changeFocus(self, event):
        event.widget.tk_focusNext().focus()

    def connectSignal(self, connected):
        if connected:
            self.reconnect()
        else:            
            # if currently sampling, stop sampling
            if self.sampling:
                self.sample()
            
            self.disableBarcodeUI()
            self.disableAssignmentUI()

    def reconnect(self):
        self.handler.busy()
        
        try:
            self.handler.connectToast()
            self.handler.debugMsg("connecting Toast...")
            
        except NoDeviceError:
            self.dcoVar.set("No device detected")
            self.assignmentVar.set("No device detected")
            self.barcodeVar.set("No device detected")

            # disable ToastFrame and GraphFrame UI, keep reconnect button on

            self.disableBarcodeUI()
            self.disableAssignmentUI()
            self.reloadButton.config(state=NORMAL, cursor="hand2")            

        except UnexpectedResponseError:
            print "ToastFrame: error on node"
        except:
            print "ToastFrame: connection error"
        else:
            
            self.enableBarcodeUI()
            self.enableAssignmentUI()
            self.handler.graphFrame.connectSignal(True)
            self.handler.adcFrame.toastSignal(True)        
            self.redrawDCO()
            self.redrawBarcode()
            self.redrawAssignments()
            
        self.handler.notbusy()    

    def reset(self):
        self.handler.busy()
        if self.barcodeSet:
            self.handler.databaseRemoveSensors()
        self.handler.resetToast()
        self.reconnect()

    
    def sample(self):
        if self.sampling:
            self.sampling = False
            
            self.handler.stopSampling()
            self.enableBarcodeUI()
            self.enableAssignmentUI()
            self.sampleButton.config(state=NORMAL, text="Sample", cursor="hand2")
        else:            
            self.sensors = []
            for i in range(0,8):
                if self.assignments[0][i] is not None:
                    self.sensors.append(i)
            
            if self.sensors:
                self.sampling = True                
                self.disableBarcodeUI()
                self.disableAssignmentUI()
                self.sampleButton.config(state=NORMAL, text="Stop", cursor="hand2")
                self.handler.startSampling(self.sensors)


    def redrawDCO(self):
        try:
            dcoStr = self.handler.getDCOSettings()
        except TagNotFoundError:
            self.dcoVar.set("Update DCO")
        except UnexpectedResponseError:
            self.dcoVar.set("DCO error")
        except:
            print "ToastFrame: dco error"
        else:
            self.dcoVar.set(dcoStr)
    

    def redrawBarcode(self):
        self.barcodeArray = []
        
        try:
            barcodeStr = self.handler.getToastBarcode()
        except TagNotFoundError:
            self.barcodeVar.set("No barcode set")
            self.barcodeVarLabel.config(fg="black")
            self.newBarcodeEntry.focus_set()
            self.barcodeSet = False
            self.disableAssignmentUI()
        except Exception:
            self.barcodeVar.set("Read error")
            self.barcodeVarLabel.config(fg="red")
            self.disableAssignmentUI()
        else:
            self.barcodeVar.set(barcodeStr)
            self.barcodeVarLabel.config(fg="black")
            self.barcodeSet = True
            
            # set toast type
            barcode = int(barcodeStr, 16)
            for i in range(0,8):
                self.barcodeArray.append((barcode >> (i*8)) & 0xFF) # byte array is little endian
                
            self.toastType = self.barcodeArray[7]
            self.handler.toastType = self.toastType
            
            # enable assignment UI, 
            self.enableAssignmentUI()


    def updateBarcodeKey(self, event):
        self.updateBarcode()
        self.sensor0newIDEntry.focus()

    def updateBarcode(self):
        
        if self.barcodeSet:
            if not tkMessageBox.askokcancel("Warning", "Barcode already set. Do you wish to overwrite?", parent=self.parent):
                self.newBarcodeVar.set("")
                return
            
        self.handler.busy()
        
        self.barcodeArray = []
        
        # first check if the barcode is an integer
        try:
            barcode = int(self.newBarcodeVar.get(), 16)
            for i in range(0,8):
                self.barcodeArray.append((barcode >> (i*8)) & 0xFF) # byte array is little endian
                
            self.toastType = self.barcodeArray[7]
            self.handler.toastType = self.toastType
            
        except ValueError:
            self.barcodeVar.set("Barcode not an integer")
            self.barcodeVarLabel.config(fg="red")
        else:
            # check if the barcode type is a Toast
            print "type: ", self.toastType
            if self.toastType != self.TYPE_TOAST and self.toastType != self.TYPE_MINITOAST:
                self.barcodeVar.set("Barcode incorrect type")
                self.barcodeVarLabel.config(fg="red")
            else:
            
                # assign barcode to toast
                try:
                    self.handler.setToastBarcode(self.newBarcodeVar.get())
                except (InvalidInputError, UnexpectedResponseError):
                    self.barcodeVar.set("Update failed")
                    self.barcodeVarLabel.config(fg="red")
                except:
                    print "ToastFrame: barcode error"
                else:    
                    self.handler.databaseToast()
                    self.newBarcodeVar.set("")
                    self.redrawBarcode()
                    self.redrawAssignments()
            
        self.handler.notbusy()


    def redrawAssignments(self):

        if self.toastType != self.TYPE_TOAST and self.toastType != self.TYPE_MINITOAST:
            return
            
        try:
            self.assignments = self.handler.getAssignments()
        except TagNotFoundError:
            self.assignmentVar.set("No assignments set")
            self.assignments = deepcopy(self.EMPTY_ASSIGNMENTS)
        except Exception:
            self.assignmentVar.set("Read error")
            self.assignmentVarLabel.config(fg="red")
            self.assignments = deepcopy(self.EMPTY_ASSIGNMENTS)
        else:
            self.assignmentVar.set("")
            self.assignmentVarLabel.config(fg="black")

        self.nSensors=8
        
        for i in range(0,8):        
            tmpID = self.assignments[0][i]
            if tmpID:
                tmpStr = "%02X%02X" % ((tmpID >> 8) & 0xFF, tmpID & 0xFF)
                tmpType = "%02X" % self.assignments[1][i]
                typeVal = self.assignments[1][i]
            else:
                tmpStr = "N/A"
                tmpType = "N/A"                
                # reset fields in assignment array
                # 0 means 'reset channel on toast' while None means 'ignore field'
                self.assignments[0][i] = None
                self.assignments[1][i] = None
                typeVal = 0
            
            self.stIDVars[i].set(tmpStr)
            self.stTypeVars[i].set(tmpType)
            self.handler.toastSensorType[i]= typeVal

            
        # if toast is mini toast, preassign channel 1 and channel 2
        if self.toastType == self.TYPE_MINITOAST and self.barcodeArray:
            sens0type = "%02X" % 32
            sens1type = "%02X" % 33
            id = "%02X%02X" % (self.barcodeArray[1], self.barcodeArray[0])
            idInt = int(id, 16)
            self.nSensors = 3
            
            if self.assignments[0][0] != idInt or self.assignments[1][0] != 32:
                self.stNewIDVars[0].set(sens0type + id)
            
            if self.assignments[0][1] != idInt or self.assignments[1][1] != 33:
                self.stNewIDVars[1].set(sens1type + id) 

            if self.assignments:
                self.updateAssignments()


    def updateAssignmentsKey(self, event):
        self.updateAssignments()

    def updateAssignments(self):
        
        if not self.barcodeSet:    
            self.assignmentVar.set("Toast ID must be set")
            self.assignmentVarLabel.config(fg="red")
            return
        
        self.assignmentVar.set("")
        change = False
        duplicate = {}
        
        for i in range(0,8):
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
                for i in range(0,8):
                    self.stNewIDVars[i].set('')
                self.redrawAssignments()
                
                # insert into database
                self.handler.databaseSensors()
            self.handler.notbusy()
            


