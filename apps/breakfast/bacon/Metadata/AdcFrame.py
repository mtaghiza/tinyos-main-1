
import Tkinter
from Tkinter import *

from BreakfastError import *

class AdcFrame(Frame):

    def __init__(self, parent, handler, **args):
        Frame.__init__(self, parent, **args)
        
        self.handler = handler

        self.initUI()
        self.disableUI()
        self.pack()

    def initUI(self):
        self.adcBaconLabel = Label(self, text="Bacon ADC Calibration:")
        self.adcBaconLabel.grid(column=1, row=1)
        self.adcToastLabel = Label(self, text="Toast ADC Calibration:")
        self.adcToastLabel.grid(column=1, row=2)

        self.bFrame = Frame(self)
        self.adc0BaconLabel = Label(self.bFrame, text="Gain:")
        self.adc1BaconLabel = Label(self.bFrame, text="Offset:")
        self.adc2BaconLabel = Label(self.bFrame, text="1.5T30:")
        self.adc3BaconLabel = Label(self.bFrame, text="1.5T85:")
        self.adc4BaconLabel = Label(self.bFrame, text="2.0T30:")
        self.adc5BaconLabel = Label(self.bFrame, text="2.0T85")
        self.adc6BaconLabel = Label(self.bFrame, text="2.5T30:")
        self.adc7BaconLabel = Label(self.bFrame, text="2.5T85")
        self.adc8BaconLabel = Label(self.bFrame, text="1.5VREF:")
        self.adc9BaconLabel = Label(self.bFrame, text="2.0VREF:")
        self.adc10BaconLabel = Label(self.bFrame, text="2.5VREF:")
        for i in range(0,11):
            eval("self.adc%dBaconLabel.grid(column=%d*2+1, row=%d)" % (i, i, 1))

        self.adc0BaconVar = IntVar()
        self.adc1BaconVar = IntVar()
        self.adc2BaconVar = IntVar()
        self.adc3BaconVar = IntVar()
        self.adc4BaconVar = IntVar()
        self.adc5BaconVar = IntVar()
        self.adc6BaconVar = IntVar()
        self.adc7BaconVar = IntVar()
        self.adc8BaconVar = IntVar()
        self.adc9BaconVar = IntVar()
        self.adc10BaconVar = IntVar()
        self.adc0BaconVarLabel = Label(self.bFrame, textvar=self.adc0BaconVar)
        self.adc1BaconVarLabel = Label(self.bFrame, textvar=self.adc1BaconVar)
        self.adc2BaconVarLabel = Label(self.bFrame, textvar=self.adc2BaconVar)
        self.adc3BaconVarLabel = Label(self.bFrame, textvar=self.adc3BaconVar)
        self.adc4BaconVarLabel = Label(self.bFrame, textvar=self.adc4BaconVar)
        self.adc5BaconVarLabel = Label(self.bFrame, textvar=self.adc5BaconVar)
        self.adc6BaconVarLabel = Label(self.bFrame, textvar=self.adc6BaconVar)
        self.adc7BaconVarLabel = Label(self.bFrame, textvar=self.adc7BaconVar)
        self.adc8BaconVarLabel = Label(self.bFrame, textvar=self.adc8BaconVar)
        self.adc9BaconVarLabel = Label(self.bFrame, textvar=self.adc9BaconVar)
        self.adc10BaconVarLabel = Label(self.bFrame, textvar=self.adc10BaconVar)
        for i in range(0,11):
            eval("self.adc%dBaconVarLabel.grid(column=(%d+1)*2, row=%d)" % (i, i, 1))
        self.bFrame.grid(column=2, row=1)


        self.tFrame = Frame(self)
        self.adc0ToastLabel = Label(self.tFrame, text="Gain:")
        self.adc1ToastLabel = Label(self.tFrame, text="Offset:")
        self.adc2ToastLabel = Label(self.tFrame, text="1.5VREF:")
        self.adc3ToastLabel = Label(self.tFrame, text="1.5T30:")
        self.adc4ToastLabel = Label(self.tFrame, text="1.5T85:")
        self.adc5ToastLabel = Label(self.tFrame, text="2.5VREF:")
        self.adc6ToastLabel = Label(self.tFrame, text="2.5T30:")
        self.adc7ToastLabel = Label(self.tFrame, text="2.5T85")
        for i in range(0,8):
            eval("self.adc%dToastLabel.grid(column=%d*2+1, row=%d)" % (i, i, 2))

        self.adc0ToastVar = IntVar()
        self.adc1ToastVar = IntVar()
        self.adc2ToastVar = IntVar()
        self.adc3ToastVar = IntVar()
        self.adc4ToastVar = IntVar()
        self.adc5ToastVar = IntVar()
        self.adc6ToastVar = IntVar()
        self.adc7ToastVar = IntVar()
        self.adc0ToastVarLabel = Label(self.tFrame, textvar=self.adc0ToastVar)
        self.adc1ToastVarLabel = Label(self.tFrame, textvar=self.adc1ToastVar)
        self.adc2ToastVarLabel = Label(self.tFrame, textvar=self.adc2ToastVar)
        self.adc3ToastVarLabel = Label(self.tFrame, textvar=self.adc3ToastVar)
        self.adc4ToastVarLabel = Label(self.tFrame, textvar=self.adc4ToastVar)
        self.adc5ToastVarLabel = Label(self.tFrame, textvar=self.adc5ToastVar)
        self.adc6ToastVarLabel = Label(self.tFrame, textvar=self.adc6ToastVar)
        self.adc7ToastVarLabel = Label(self.tFrame, textvar=self.adc7ToastVar)
        for i in range(0,8):
            eval("self.adc%dToastVarLabel.grid(column=(%d+1)*2, row=%d)" % (i, i, 2))
        self.tFrame.grid(column=2, row=2)

    def enableUI(self):
        for i in range(0,11):
            eval("self.adc%dBaconVarLabel.config(state=NORMAL)" % i)
            eval("self.adc%dBaconLabel.config(state=NORMAL)" % i)

        for i in range(0,8):
            eval("self.adc%dToastVarLabel.config(state=NORMAL)" % i)
            eval("self.adc%dToastLabel.config(state=NORMAL)" % i)

        self.adcBaconLabel.config(state=NORMAL)
        self.adcToastLabel.config(state=NORMAL)

    def disableUI(self):
        for i in range(0,11):
            eval("self.adc%dBaconVarLabel.config(state=DISABLED)" % i)
            eval("self.adc%dBaconLabel.config(state=DISABLED)" % i)

        for i in range(0,8):
            eval("self.adc%dToastVarLabel.config(state=DISABLED)" % i)
            eval("self.adc%dToastLabel.config(state=DISABLED)" % i)

        self.adcBaconLabel.config(state=DISABLED)
        self.adcToastLabel.config(state=DISABLED)

    def connectSignal(self, connected):
        if connected:
            self.enableUI()
            self.redrawBacon()
        else:
            self.disableUI()

    def redrawBacon(self):
        try:
            adcList = self.handler.getBaconADCSettings()
        except:
            pass
        else:
            for i in range(0, len(adcList)):
                eval("self.adc%dBaconVar.set(%d)" % (i, adcList[i]))

    def sampleSignal(self, sampling):
        if sampling:
            self.disableUI()
        else:
            self.enableUI()

    def toastSignal(self, detected):
        if detected:
            self.enableUI()
            self.redrawToast()
        else:
            self.disableUI()

    def redrawToast(self):        
        try:
            adcList = self.handler.getToastADCSettings()
        except:
            pass
        else:
            for i in range(0, len(adcList)):
                eval("self.adc%dToastVar.set(%d)" % (i, adcList[i]))
                
    
