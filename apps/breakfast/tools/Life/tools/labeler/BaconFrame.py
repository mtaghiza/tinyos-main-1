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
        self.emptyFrame = Frame(self)
        self.emptyFrame.grid(column=1, row=1)
        
        self.currentLabel = Label(self, text="Current Value")
        self.currentLabel.grid(column=2, row=1)
        
        self.newLabel = Label(self, text="New Value")
        self.newLabel.grid(column=3, row=1, columnspan=2)
        
        # row 2
        self.barcodeLabel = Label(self, text="Node ID:", width=11, anchor=E)
        self.barcodeLabel.grid(column=1, row=2)
        
        self.barcodeVar = StringVar()
        self.barcodeVar.set("Not available")
        
        self.barcodeVarLabel = Label(self, textvariable=self.barcodeVar, width=18)
        self.barcodeVarLabel.grid(column=2, row=2)
        
        self.newBarcodeVar = StringVar()
        self.barcodeEntry = Entry(self, textvariable=self.newBarcodeVar, width=18)
        self.barcodeEntry.bind("<Return>", self.updateBarcodeKey)
        self.barcodeEntry.grid(column=3, row=2, columnspan=2)
        
        # row 3
        self.mfrLabel = Label(self, text="Mfr. ID:", width=11, anchor=E)
        self.mfrLabel.grid(column=1, row=3, sticky=E)
        
        self.mfrVar = StringVar()
        self.mfrVar.set("Not available")
        self.mfrVarLabel = Label(self, textvariable=self.mfrVar, width=18)
        self.mfrVarLabel.grid(column=2, row=3)
        
        self.reconnectButton = Button(self, text="Reload", command=self.reconnect, width=6)
        self.reconnectButton.grid(column=3, row=3)

        self.barcodeButton = Button(self, text="Save", command=self.updateBarcode, width=6)
        self.barcodeButton.grid(column=4, row=3)

    def enableUI(self):
        self.currentLabel.config(state=NORMAL)
        self.newLabel.config(state=NORMAL)
        self.barcodeLabel.config(state=NORMAL)
        self.mfrLabel.config(state=NORMAL)
        self.barcodeVarLabel.config(state=NORMAL)
        self.barcodeEntry.config(state=NORMAL)
        self.barcodeButton.config(state=NORMAL, cursor="hand2")
        self.reconnectButton.config(state=NORMAL, cursor="hand2")
        self.mfrVarLabel.config(state=NORMAL)

    def disableUI(self):
        self.currentLabel.config(state=DISABLED)
        self.newLabel.config(state=DISABLED)
        self.barcodeLabel.config(state=DISABLED)
        self.mfrLabel.config(state=DISABLED)
        self.barcodeVarLabel.config(state=DISABLED)
        self.barcodeEntry.config(state=DISABLED)
        self.barcodeButton.config(state=DISABLED, cursor="")
        self.reconnectButton.config(state=DISABLED, cursor="")
        self.mfrVarLabel.config(state=DISABLED)


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
            self.barcodeVar.set("Barcode not an integer")
            self.barcodeVarLabel.config(fg="red")
        except TypeError:
            self.barcodeVar.set("Barcode incorrect type")
            self.barcodeVarLabel.config(fg="red")        
        except:
            self.barcodeVar.set("Update failed")
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
    