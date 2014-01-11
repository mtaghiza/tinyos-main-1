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

import Queue
import Tkinter
import tkMessageBox
from Tkinter import *

from tools.labeler.BreakfastError import *
from tools.SimPy.SimPlot import * 

HEIGHT = 420

class GraphFrame(Frame):

    def __init__(self, parent, handler, simplot, **args):
        Frame.__init__(self, parent, **args)
        
        self.parent = parent
        self.handler = handler
        self.simplot = simplot
        self.graph = None
        
        self.tSensors = 8
        self.bSensors = 3

        self.count = [0,0,0,0,0,0,0,0]
        self.values = {}
        for i in range(0,8):
            self.values[i] = []

        self.sampling = False
        
        self.initUI()
        self.disableUI()       
        self.pack()

    def initUI(self):
        self.initGraph()
        #
        self.sFrame = Frame(self, width=144, height=488, relief=SUNKEN)
        self.sFrame.grid(column=1, row=1)
        self.sFrame.grid_propagate(False)
        #
        self.initSampleUI(self.sFrame)
        #

    def initSampleUI(self, sFrame):

        crow= 1
        # row 1, vertical spacer
        self.vSpace0 = Frame(self.sFrame, height=16)
        self.vSpace0.grid(column=1,row=crow)

        # row 2, sampleButton
        crow += 1
        self.sampleButton = Button(self.sFrame, text="Start sampling", command=self.sample, width=15)
        self.sampleButton.grid(column=1, row=crow,columnspan=3,sticky=N) 

        # row 3, resetButton
        crow += 1
        self.resetButton = Button(self.sFrame, text="Reset sampling", command=self.resetStat, width=15)
        self.resetButton.grid(column=1, row=crow,columnspan=3,sticky=S) 

        # row 3, vertical spacer
        crow += 1
        self.vSpace1 = Frame(self.sFrame, height=19)
        self.vSpace1.grid(column=1,row=crow)
        
        #row 4, labels
        crow += 1
        self.meanLabel1 = Label(self.sFrame, text=" Mean", width=5)
        self.meanLabel1.grid(column=1, row=crow)
        
        self.stdLabel1 = Label(self.sFrame, text="  Std", width=5)
        self.stdLabel1.grid(column=2, row=crow)
        
        self.countLabel1 = Label(self.sFrame, text="Count")
        self.countLabel1.grid(column=3, row=crow)

        # row 5-8, sensor data values
        baconRow = crow+1

        # row 9, vertical spacer        
        crow += 4
        self.vSpace2 = Frame(self.sFrame, width=10,height=12)
        self.vSpace2.grid(column=1,row=crow)

        # row
        crow += 1
        self.convertVar = IntVar()
        self.calButton = Radiobutton(self.sFrame,text="Calibrated", padx=30, command=self.convert, variable=self.convertVar, value=0)
        self.calButton.grid(column=1, row=crow, columnspan=3, sticky=W)        
        
        crow += 1
        self.rawButton = Radiobutton(self.sFrame, text="Raw", padx=30, command=self.convert, variable=self.convertVar, value=1)
        self.rawButton.grid(column=1, row=crow, columnspan=3, sticky=W)
        self.conversion = True
        self.sampleFmt = "%0.2f"
        
        crow += 1
        self.vSpace4 = Frame(self.sFrame, width=3, height=10)
        self.vSpace4.grid(column=1,row=crow)

        crow += 1
        self.snapButton = Button(self.sFrame, text="Write Snapshot", width=15, command=self.convert)
        self.snapButton.grid(column=1, row=crow, columnspan=3)

        # row 12
        crow += 1
        self.vSpace4 = Frame(self.sFrame, width=3, height=19)
        self.vSpace4.grid(column=1,row=crow)

        # row 13, labels
        crow += 1
        self.meanLabel2 = Label(self.sFrame, text=" Mean", width=5)
        self.meanLabel2.grid(column=1, row=crow)
        
        self.stdLabel2 = Label(self.sFrame, text="  Std", width=5)
        self.stdLabel2.grid(column=2, row=crow)
        
        self.countLabel2 = Label(self.sFrame, text="Count", width=5)
        self.countLabel2.grid(column=3, row=crow)

        self.sampleMeanVars   = []
        self.sampleMeanLabels = []
        self.sampleStdVars    = []
        self.sampleStdLabels  = []
        self.sampleCountVars  = []
        self.sampleCountLabels= []
        #
        # indexes 0..7  correspond to the Toast sensors
        # indexes 8..11 correspond to the Bacon sensors
        #
        crow += 1
        for i in range(0,11):
            rw = i+crow
            if i>7:
                rw = i-8 + baconRow
            #
            self.sampleMeanVars.append(DoubleVar())
            self.sampleStdVars.append(DoubleVar())
            self.sampleCountVars.append(IntVar())
            self.sampleMeanLabels.append(Label(self.sFrame, width=6,textvariable=self.sampleMeanVars[i], anchor=E))            
            self.sampleStdLabels.append(Label(self.sFrame, width=6,textvar=self.sampleStdVars[i], anchor=E))
            self.sampleCountLabels.append(Label(self.sFrame, width=4, textvar=self.sampleCountVars[i], anchor=E))
            #
            self.sampleMeanLabels[i].grid(column=1, row=rw, sticky=E)            
            self.sampleStdLabels[i].grid(column=2, row=rw, sticky=E)
            self.sampleCountLabels[i].grid(column=3, row=rw) 
        

    def enableUI(self):
        self.initGraph()
        self.resetStat()
        self.graph.grid(column=1, row=1)  
        self.setSampleUIState(NORMAL,"hand2")
        

 
    def disableUI(self):
        self.graph.grid_forget()
        self.resetStat()
        self.setSampleUIState(DISABLED,"")


    def connectSignal(self, connected):
        if connected:
            self.enableUI()            
        else:
            # if currently sampling, stop sampling
            if self.sampling:
                self.sample()
            
            self.disableUI()


    def setSampleUIState(self,st,cur):
        self.meanLabel1.config(state=st)
        self.stdLabel1.config(state=st)
        self.countLabel1.config(state=st)
        self.meanLabel2.config(state=st)
        self.stdLabel2.config(state=st)
        self.countLabel2.config(state=st)        
        self.sampleButton.config(state=st, cursor=cur)
        self.resetButton.config(state=st, cursor=cur)
        self.rawButton.config(state=st, cursor=cur)
        self.calButton.config(state=st, cursor=cur)
        self.snapButton.config(state=st, cursor=cur)
        
        self.tSensors = 8 if self.handler.toastType == self.handler.TYPE_TOAST else 3
        
        # toast
        for i in range (0,self.tSensors):
            self.sampleMeanLabels[i].config(state=st)        
            self.sampleStdLabels[i].config(state=st)
            self.sampleCountLabels[i].config(state=st)
        for i in range (self.tSensors,8):
            self.sampleMeanLabels[i].config(state=DISABLED)        
            self.sampleStdLabels[i].config(state=DISABLED)
            self.sampleCountLabels[i].config(state=DISABLED)

        # bacon
        for i in range(8,8+self.bSensors):
            self.sampleMeanLabels[i].config(state=st)        
            self.sampleStdLabels[i].config(state=st)
            self.sampleCountLabels[i].config(state=st)


    def initGraph(self):
        if self.graph:
            self.graph.grid_forget()
        
        bgcolor = self.cget('bg')
                
        self.gFrame = Frame(self, width=540, height=400)
        self.gFrame.grid_propagate(False)
        self.gFrame.grid(column=2, row=1)       # in the high level layout        
        #
        self.graph = self.simplot.makeGraphBase(self.gFrame, 540, 400, xtitle="time", ytitle="ADC", background="white")


    def resetGraph(self):
        oldGraph = self.graph
        self.graph = self.simplot.makeGraphBase(self.gFrame, 540, 400, xtitle="time", ytitle="ADC")  
        self.graph.grid(column=0, row=1)
        oldGraph.grid_forget()
    
    def resetStat(self):       
        # create a list of lists organized by sensor id,
        # containing a time series each. ts[i] is the 2D list of sensor i
        
        self.tsPoints = []
        for i in range(0,self.tSensors):
            self.tsPoints.append([])
            self.count[i] = 0
            
            self.sampleMeanVars[i].set(0.0)
            self.sampleStdVars[i].set(0.0)
            self.sampleCountVars[i].set(0)

    #
    # Graph and stat update
    #    
    def sample(self):
        if self.sampling:
            self.sampling = False
            
            self.handler.stopSampling()
            self.enableUI()
            self.sampleButton.config(state=NORMAL, text="Start sampling", cursor="hand2")
        else:            
            self.sensors = []
                       
            for i in range(0,8):
                # only sample channels with sensors assigned
                #if self.handler.toastFrame.assignments[0][i]:
                self.sensors.append(i)
            
            if self.sensors:
                self.sampling = True               
                self.nSensors = sum(x>0 for x in self.handler.toastSensorType)               
               
                self.sampleButton.config(state=NORMAL, text="Stop sampling", cursor="hand2")
                self.handler.startSampling(self.sensors)
            else:
                tkMessageBox.showinfo("Labeler", "No sensors to sample", parent=self.parent)

    def sampleSignal(self, sampling):
        #self.sampling = sampling
        if self.sampling:
            self.resetGraph()
            self.resetStat()
            self.graph.after(1000, self.update)

    def convert(self):
        # if conversion format changes, reset sampling, and set variables
        self.resetStat()
        if self.convertVar.get()==0:
            self.conversion = True
            self.sampleFmt = "%0.2f"
        else:
            self.conversion = False
            self.sampleFmt = "%0.1f"


    def convertSensor(self, sensorid, value):
        #
        # conversions from raw ADC to known sensor types
        #
        if self.conversion:
            
            # divide by 4096, and multiply with reference voltage
            v = value/4096.0000000*2.5      # the value in Volts

            # get sensor type
            type =  self.handler.toastSensorType[sensorid]

            if type == 33:        # 0x21: built-in voltage divider
                v *= 2
                
            elif type == 32:      # 0x20: built-in US Sensor thermistor
                x = math.log(v/(3.3-v))
                y = 0.002*x*x-0.07716*x+5.69808
                v =math.exp(y)-273.15
            elif type == 19:      # 0x13: YSI 44006RC thermistor
                x = math.log(v/(3.3-v))
                y = 0.001982*x*x-0.083863*x+5.697970
                v =math.exp(y)-273.15
            return v
        else:
            return value
        

    def update(self):
        if self.sampling:
            try:
                while(True):
                    
                    self.handler.debugMsg(self.tSensors)
                    
                    # sensors are labeled 1-8
                    (sensor, adc) = self.handler.getToastReadings()
                    if sensor <= self.tSensors:
                        self.count[sensor-1] += 1
                        #
                        val = self.convertSensor(sensor-1,adc)
                        self.tsPoints[sensor-1].append([self.count[sensor-1]-1,val])

            except Queue.Empty:
                pass
            
            self.calculateStats()
            self.drawPoints()
            self.graph.after(1000, self.update)

    def drawPoints(self):    
        self.graph.clear() 
        self.symbols = []
        self.colors  = ["maroon","slate blue","sea green","gold","peru","sienna","snow2","snow2"]

        for i in range(0,self.tSensors):
            self.symbols.append(self.simplot.makeSymbols(self.tsPoints[i], size=1, color="seashell4", fillcolor=self.colors[i]))
        self.objects = self.simplot.makeGraphObjects(self.symbols)
        
        if len(self.tsPoints[0])>100:
            self.resetStat()
        self.graph.draw(self.objects, xaxis=(0,100), yaxis="automatic")
 

    def calculateStats(self):

        for i in range(0,self.tSensors):
            if self.count[i]:
                lo = 0
                hi = self.count[i]
                # moving box average of at most 8 points
                if (hi-lo)>8:
                    lo = hi-8
                x0 = 0
                x1 = 0
                x2 = 0
                for j in range(lo,hi):
                    val =  self.tsPoints[i][j][1]*1.00000
                    x1 += val
                    x2 += val*val
                    x0 += 1
                     
                x1 /= x0
                x2 /= x0
                x2 = math.sqrt(x2-x1*x1)

                sx1 = self.sampleFmt % x1
                sx2 = self.sampleFmt % x2
                self.sampleMeanVars[i].set(sx1)
                self.sampleStdVars[i].set(sx2)
                self.sampleCountVars[i].set(self.count[i])

