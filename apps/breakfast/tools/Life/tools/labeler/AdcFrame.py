
import Tkinter
from Tkinter import *

from tools.labeler.BreakfastError import *

class AdcFrame(Frame):

    def __init__(self, parent, handler, **args):
        Frame.__init__(self, parent, **args)
        
        self.handler = handler

        self.initUI()
        self.disableUI()
        self.pack()

    def initUI(self):
        self.adcBaconLabel = Label(self, text="Node Factory ADC Constants:")
        self.adcBaconLabel.grid(column=1, row=2, sticky=E)
        self.adcToastLabel = Label(self, text="Multiplex Factory ADC Constants:")
        self.adcToastLabel.grid(column=1, row=3, sticky=E)

        self.adc0BaconLabel = Label(self, text="Gain", width=10)
        self.adc1BaconLabel = Label(self, text="Offset", width=10)
        self.adc2BaconLabel = Label(self, text="1.5T30", width=10)
        self.adc3BaconLabel = Label(self, text="1.5T85", width=10)
        self.adc4BaconLabel = Label(self, text="2.0T30", width=10)
        self.adc5BaconLabel = Label(self, text="2.0T85", width=10)
        self.adc6BaconLabel = Label(self, text="2.5T30", width=10)
        self.adc7BaconLabel = Label(self, text="2.5T85", width=10)
        self.adc8BaconLabel = Label(self, text="1.5VREF", width=10)
        self.adc9BaconLabel = Label(self, text="2.0VREF", width=10)
        self.adc10BaconLabel = Label(self, text="2.5VREF", width=10)
        for i in range(0,11):
            eval("self.adc%dBaconLabel.grid(column=%d+2, row=%d)" % (i, i, 1))

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
        self.adc0BaconVarLabel = Label(self, textvar=self.adc0BaconVar)
        self.adc1BaconVarLabel = Label(self, textvar=self.adc1BaconVar)
        self.adc2BaconVarLabel = Label(self, textvar=self.adc2BaconVar)
        self.adc3BaconVarLabel = Label(self, textvar=self.adc3BaconVar)
        self.adc4BaconVarLabel = Label(self, textvar=self.adc4BaconVar)
        self.adc5BaconVarLabel = Label(self, textvar=self.adc5BaconVar)
        self.adc6BaconVarLabel = Label(self, textvar=self.adc6BaconVar)
        self.adc7BaconVarLabel = Label(self, textvar=self.adc7BaconVar)
        self.adc8BaconVarLabel = Label(self, textvar=self.adc8BaconVar)
        self.adc9BaconVarLabel = Label(self, textvar=self.adc9BaconVar)
        self.adc10BaconVarLabel = Label(self, textvar=self.adc10BaconVar)
        for i in range(0,11):
            eval("self.adc%dBaconVarLabel.grid(column=%d+2, row=%d)" % (i, i, 2))


        #CAL_ADC_25T85 = 7
        #CAL_ADC_25T30 = 6
        #CAL_ADC_25VREF_FACTOR = 5
        #CAL_ADC_15T85 = 4
        #CAL_ADC_15T30 = 3
        #CAL_ADC_15VREF_FACTOR = 2 
        #CAL_ADC_OFFSET = 1
        #CAL_ADC_GAIN_FACTOR = 0
        self.adc0ToastVar = IntVar()
        self.adc1ToastVar = IntVar()
        self.adc2ToastVar = IntVar()
        self.adc3ToastVar = IntVar()
        self.adc4ToastVar = IntVar()
        self.adc5ToastVar = IntVar()
        self.adc6ToastVar = IntVar()
        self.adc7ToastVar = IntVar()
        self.adc0ToastVarLabel = Label(self, textvar=self.adc0ToastVar) 
        self.adc1ToastVarLabel = Label(self, textvar=self.adc1ToastVar) 
        self.adc2ToastVarLabel = Label(self, textvar=self.adc2ToastVar) 
        self.adc3ToastVarLabel = Label(self, textvar=self.adc3ToastVar) 
        self.adc4ToastVarLabel = Label(self, textvar=self.adc4ToastVar) 
        self.adc5ToastVarLabel = Label(self, textvar=self.adc5ToastVar) 
        self.adc6ToastVarLabel = Label(self, textvar=self.adc6ToastVar) 
        self.adc7ToastVarLabel = Label(self, textvar=self.adc7ToastVar) 

        self.adc0ToastVarLabel.grid(column=2, row=3)    # gain
        self.adc1ToastVarLabel.grid(column=3, row=3)    # offset
        self.adc2ToastVarLabel.grid(column=10, row=3)   # 15VREF_FACTOR
        self.adc3ToastVarLabel.grid(column=4, row=3)    # 15T30
        self.adc4ToastVarLabel.grid(column=5, row=3)    # 15T85
        self.adc5ToastVarLabel.grid(column=12, row=3)   # 25VREF_FACTOR
        self.adc6ToastVarLabel.grid(column=8, row=3)    # 25T30
        self.adc7ToastVarLabel.grid(column=9, row=3)    # 25T85



    def enableUI(self):
        for i in range(0,11):
            eval("self.adc%dBaconVarLabel.config(state=NORMAL)" % i)
            eval("self.adc%dBaconLabel.config(state=NORMAL)" % i)

        for i in range(0,8):
            eval("self.adc%dToastVarLabel.config(state=NORMAL)" % i)

        self.adcBaconLabel.config(state=NORMAL)
        self.adcToastLabel.config(state=NORMAL)

    def disableUI(self):
        for i in range(0,11):
            eval("self.adc%dBaconVarLabel.config(state=DISABLED)" % i)
            eval("self.adc%dBaconLabel.config(state=DISABLED)" % i)

        for i in range(0,8):
            eval("self.adc%dToastVarLabel.config(state=DISABLED)" % i)

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
            print "AdcFrame: no node adc settings"
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
            print "AdcFrame: no multiplexer adc settings"
            pass
        else:
            for i in range(0, len(adcList)):
                eval("self.adc%dToastVar.set(%d)" % (i, adcList[i]))
                
    
