import time
import Tkinter
from Tkinter import *

from BreakfastError import *

class BaconFrame(Frame):

    def __init__(self, parent, handler, **args):
        Frame.__init__(self, parent, **args)
        
        self.handler = handler

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
        self.barcodeLabel = Label(self, text="Bacon ID:", width=11, anchor=E)
        self.barcodeLabel.grid(column=1, row=2)
        
        self.barcodeVar = StringVar()
        self.barcodeVar.set("<not available>")
        
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
        self.mfrVar.set("<not available>")
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
            mfrStr = "<not available>"
            
            try:
                mfrStr = self.handler.getMfrID()
            except Exception:
                self.mfrVar.set("<connection error>")
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
        self.handler.publicDisconnect()
        time.sleep(1)
        self.handler.publicConnect()

    def sampleSignal(self, sampling):
        if sampling:
            self.disableUI()
        else:
            self.enableUI()

    def updateBarcodeKey(self, event):
        self.updateBarcode()

    def updateBarcode(self):
        self.handler.busy()
        try:
            self.handler.setBaconBarcode(self.newBarcodeVar.get())
        except ValueError:
            self.barcodeVar.set("<barcode not an integer>")
            self.barcodeVarLabel.config(fg="red")
        except:
            self.barcodeVar.set("<update failed>")
            self.barcodeVarLabel.config(fg="red")
        else:    
            self.redrawBarcode()
            self.newBarcodeVar.set("")
            self.handler.insertBacon()
        self.handler.notbusy()
    
    def redrawBarcode(self):
        try:
            barcodeStr = self.handler.getBaconBarcode()
        except TagNotFoundError:
            self.barcodeVar.set("<barcode not set>")
            self.barcodeEntry.focus_set()
        except:
            self.barcodeVar.set("<connection error>")
            self.barcodeVarLabel.config(fg="red")
        else:
            self.barcodeVar.set(barcodeStr)
            self.barcodeVarLabel.config(fg="black")
    