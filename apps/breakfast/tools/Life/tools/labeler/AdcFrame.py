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
        
        self.hSpace = Frame(self, width=40)
        self.hSpace.grid(column=0, row=1, rowspan=3)
        #
        self.adcBaconLabel = Label(self, text="Node ADC Const:")
        self.adcBaconLabel.grid(column=1, row=2, sticky=E)
        self.adcToastLabel = Label(self, text="Mux ADC Const:")
        self.adcToastLabel.grid(column=1, row=3, sticky=E)

        self.adcBaconLabels = []
        self.adcBaconVars = []
        self.adcBaconVarLabels = []
        self.lbl = ["Gain","Offset","1.5T30","1.5T85","2.0T30","2.0T85","2.5T30","2.5T85","1.5VREF","2.0VREF","2.5VREF"]
        
        for i in range(0,11):
            self.adcBaconLabels.append(Label(self,text=self.lbl[i],width=7))
            self.adcBaconLabels[i].grid(column=i+2, row=1)
        
        for i in range(0,11):
            self.adcBaconVars.append(IntVar())
            self.adcBaconVarLabels.append(Label(self,textvar=self.adcBaconVars[i]))
            self.adcBaconVarLabels[i].grid(column=i+2, row=2)
            
        #CAL_ADC_25T85 = 7
        #CAL_ADC_25T30 = 6
        #CAL_ADC_25VREF_FACTOR = 5
        #CAL_ADC_15T85 = 4
        #CAL_ADC_15T30 = 3
        #CAL_ADC_15VREF_FACTOR = 2 
        #CAL_ADC_OFFSET = 1
        #CAL_ADC_GAIN_FACTOR = 0

        self.adcToastVars = []
        self.adcToastVarLabels = []
        
        for i in range(0,8):
            self.adcToastVars.append(IntVar())
            self.adcToastVarLabels.append(Label(self,textvar=self.adcToastVars[i]))
            
        self.adcToastVarLabels[0].grid(column=2, row=3)    # gain
        self.adcToastVarLabels[1].grid(column=3, row=3)    # offset
        self.adcToastVarLabels[2].grid(column=10, row=3)   # 15VREF_FACTOR
        self.adcToastVarLabels[3].grid(column=4, row=3)    # 15T30
        self.adcToastVarLabels[4].grid(column=5, row=3)    # 15T85
        self.adcToastVarLabels[5].grid(column=12, row=3)   # 25VREF_FACTOR
        self.adcToastVarLabels[6].grid(column=8, row=3)    # 25T30
        self.adcToastVarLabels[7].grid(column=9, row=3)    # 25T85


    def enableUI(self):
        for i in range(0,11):
            self.adcBaconVarLabels[i].config(state=NORMAL)
            self.adcBaconLabels[i].config(state=NORMAL)

        for i in range(0,8):
            self.adcToastVarLabels[i].config(state=NORMAL)

        self.adcBaconLabel.config(state=NORMAL)
        self.adcToastLabel.config(state=NORMAL)

    def disableUI(self):
        for i in range(0,11):
            self.adcBaconVarLabels[i].config(state=DISABLED)
            self.adcBaconLabels[i].config(state=DISABLED)

        for i in range(0,8):
            self.adcToastVarLabels[i].config(state=DISABLED)

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
                self.adcBaconVars[i].set(adcList[i])

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
                self.adcToastVars[i].set(adcList[i])
                
