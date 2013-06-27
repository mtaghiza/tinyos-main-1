
import Tkinter
from Tkinter import *

from BreakfastError import *

class BaconFrame(Frame):

    def __init__(self, parent, handler, **args):
        Frame.__init__(self, parent, **args)
        
        self.handler = handler
        self.handler.addConnectListener(self.connectSignal)
        self.handler.addSampleListener(self.sampleSignal)

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
        self.newLabel.grid(column=3, row=1)
        
        # row 2
        self.barcodeLabel = Label(self, text="Bacon ID:")
        self.barcodeLabel.grid(column=1, row=2)
        
        self.barcodeVar = StringVar()
        self.barcodeVar.set("<not available>")
        
        self.barcodeVarLabel = Label(self, textvariable=self.barcodeVar)
        self.barcodeVarLabel.grid(column=2, row=2)
        
        self.newBarcodeVar = StringVar()
        self.barcodeEntry = Entry(self, textvariable=self.newBarcodeVar)
        self.barcodeEntry.bind("<Return>", self.updateBarcodeKey)
        self.barcodeEntry.grid(column=3, row=2)
        
        # row 3
        self.mfrLabel = Label(self, text="Manufacture ID:")
        self.mfrLabel.grid(column=1, row=3)
        
        self.mfrVar = StringVar()
        self.mfrVar.set("<not available>")
        self.mfrVarLabel = Label(self, textvariable=self.mfrVar)
        self.mfrVarLabel.grid(column=2, row=3)
        
        self.barcodeButton = Button(self, text="Update", command=self.updateBarcode)
        self.barcodeButton.grid(column=3, row=3)

    def enableUI(self):
        self.currentLabel.config(state=NORMAL)
        self.newLabel.config(state=NORMAL)
        self.barcodeLabel.config(state=NORMAL)
        self.mfrLabel.config(state=NORMAL)
        self.barcodeVarLabel.config(state=NORMAL)
        self.barcodeEntry.config(state=NORMAL)
        self.barcodeButton.config(state=NORMAL)
        self.mfrVarLabel.config(state=NORMAL)

    def disableUI(self):
        self.currentLabel.config(state=DISABLED)
        self.newLabel.config(state=DISABLED)
        self.barcodeLabel.config(state=DISABLED)
        self.mfrLabel.config(state=DISABLED)
        self.barcodeVarLabel.config(state=DISABLED)
        self.barcodeEntry.config(state=DISABLED)
        self.barcodeButton.config(state=DISABLED)
        self.mfrVarLabel.config(state=DISABLED)


    def connectSignal(self, connected):
        if connected:
            mfrStr = "<not available>"
            barcodeStr = "<not available>"
            
            try:
                mfrStr = self.handler.getMfrID()
                barcodeStr = self.handler.getBaconBarcode()
            except TagNotFoundError:
                self.barcodeVar.set("<Barcode not set>")
            except Exception:
                self.mfrVar.set("<connection error>")
                self.barcodeVar.set("<connection error>")
            else:
                self.enableUI()
                self.mfrVar.set(mfrStr)
                self.barcodeVar.set(barcodeStr)
            
        else:
            self.disableUI()

    def sampleSignal(self, sampling):
        if sampling:
            self.disableUI()
        else:
            self.enableUI()

    def updateBarcodeKey(self, event):
        self.updateBarcode()

    def updateBarcode(self):
        try:
            self.handler.setBaconBarcode(self.newBarcodeVar.get())
            barcodeStr = self.handler.getBaconBarcode()
        except ValueError:
            self.barcodeVar.set("<barcode not an integer>")
            self.barcodeVarLabel.config(fg="red")
        except:
            self.barcodeVar.set("<update failed>")
            self.barcodeVarLabel.config(fg="red")
        else:    
            self.barcodeVar.set(barcodeStr)
            self.barcodeVarLabel.config(fg="black")
            self.newBarcodeVar.set("")
    
