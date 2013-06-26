
import Tkinter
from Tkinter import *
from BreakfastError import *

import math
from SimPy.SimPlot import * 
import Queue

class GraphFrame(Frame):

    def __init__(self, parent, handler, simplot, **args):
        Frame.__init__(self, parent, **args)
        
        self.handler = handler
        self.handler.addConnectListener(self.connectSignal)
        self.handler.addSampleListener(self.sampleSignal)
        self.simplot = simplot
        self.allPoints = []

        self.mean = [0,0,0,0,0,0,0,0]
        self.count = [0,0,0,0,0,0,0,0]
        self.values = {}
        for i in range(0,8):
            self.values[i] = []
        
        self.initUI()
        self.disableUI()
        self.pack()

    def initUI(self):
        self.graph = self.simplot.makeGraphBase(self, 500, 400, xtitle="Sensor", ytitle="ADC")  
        self.sym = self.simplot.makeSymbols([[0,0]], marker="dot", size=1, fillcolor="red")
        self.obj = self.simplot.makeGraphObjects([self.sym])
        self.graph.draw(self.obj, xaxis=(0,9), yaxis=(0,4096))
        self.graph.grid(column=1, row=1)
        
        self.sFrame = Frame(self, width=400, height=300)
        self.meanLabel = Label(self.sFrame, text="Mean")
        self.meanLabel.grid(column=2, row=0)
        self.stdLabel = Label(self.sFrame, text="Std")
        self.stdLabel.grid(column=3, row=0)
        self.countLabel = Label(self.sFrame, text="Count")
        self.countLabel.grid(column=4, row=0)
        
        self.sensor0Label = Label(self.sFrame, text="Sensor 1")
        self.sensor1Label = Label(self.sFrame, text="Sensor 2")
        self.sensor2Label = Label(self.sFrame, text="Sensor 3")
        self.sensor3Label = Label(self.sFrame, text="Sensor 4")
        self.sensor4Label = Label(self.sFrame, text="Sensor 5")
        self.sensor5Label = Label(self.sFrame, text="Sensor 6")
        self.sensor6Label = Label(self.sFrame, text="Sensor 7")
        self.sensor7Label = Label(self.sFrame, text="Sensor 8")
        for i in range(0,8):
            eval("self.sensor%dLabel.grid(column=%d, row=%d+1)" % (i, 1, i))            

        self.sensor0MeanVar = DoubleVar()
        self.sensor1MeanVar = DoubleVar()
        self.sensor2MeanVar = DoubleVar()
        self.sensor3MeanVar = DoubleVar()
        self.sensor4MeanVar = DoubleVar()
        self.sensor5MeanVar = DoubleVar()
        self.sensor6MeanVar = DoubleVar()
        self.sensor7MeanVar = DoubleVar()
        self.sensor0MeanLabel = Label(self.sFrame, textvar=self.sensor0MeanVar)
        self.sensor1MeanLabel = Label(self.sFrame, textvar=self.sensor1MeanVar)
        self.sensor2MeanLabel = Label(self.sFrame, textvar=self.sensor2MeanVar)
        self.sensor3MeanLabel = Label(self.sFrame, textvar=self.sensor3MeanVar)
        self.sensor4MeanLabel = Label(self.sFrame, textvar=self.sensor4MeanVar)
        self.sensor5MeanLabel = Label(self.sFrame, textvar=self.sensor5MeanVar)
        self.sensor6MeanLabel = Label(self.sFrame, textvar=self.sensor6MeanVar)
        self.sensor7MeanLabel = Label(self.sFrame, textvar=self.sensor7MeanVar)
        for i in range(0,8):
            eval("self.sensor%dMeanLabel.grid(column=%d, row=%d+1)" % (i, 2, i))            

        self.sensor0StdVar = DoubleVar()
        self.sensor1StdVar = DoubleVar()
        self.sensor2StdVar = DoubleVar()
        self.sensor3StdVar = DoubleVar()
        self.sensor4StdVar = DoubleVar()
        self.sensor5StdVar = DoubleVar()
        self.sensor6StdVar = DoubleVar()
        self.sensor7StdVar = DoubleVar()
        self.sensor0StdLabel = Label(self.sFrame, textvar=self.sensor0StdVar)
        self.sensor1StdLabel = Label(self.sFrame, textvar=self.sensor1StdVar)
        self.sensor2StdLabel = Label(self.sFrame, textvar=self.sensor2StdVar)
        self.sensor3StdLabel = Label(self.sFrame, textvar=self.sensor3StdVar)
        self.sensor4StdLabel = Label(self.sFrame, textvar=self.sensor4StdVar)
        self.sensor5StdLabel = Label(self.sFrame, textvar=self.sensor5StdVar)
        self.sensor6StdLabel = Label(self.sFrame, textvar=self.sensor6StdVar)
        self.sensor7StdLabel = Label(self.sFrame, textvar=self.sensor7StdVar)
        for i in range(0,8):
            eval("self.sensor%dStdLabel.grid(column=%d, row=%d+1)" % (i, 3, i))            

        self.sensor0CountVar = IntVar()
        self.sensor1CountVar = IntVar()
        self.sensor2CountVar = IntVar()
        self.sensor3CountVar = IntVar()
        self.sensor4CountVar = IntVar()
        self.sensor5CountVar = IntVar()
        self.sensor6CountVar = IntVar()
        self.sensor7CountVar = IntVar()
        self.sensor0CountLabel = Label(self.sFrame, textvar=self.sensor0CountVar)
        self.sensor1CountLabel = Label(self.sFrame, textvar=self.sensor1CountVar)
        self.sensor2CountLabel = Label(self.sFrame, textvar=self.sensor2CountVar)
        self.sensor3CountLabel = Label(self.sFrame, textvar=self.sensor3CountVar)
        self.sensor4CountLabel = Label(self.sFrame, textvar=self.sensor4CountVar)
        self.sensor5CountLabel = Label(self.sFrame, textvar=self.sensor5CountVar)
        self.sensor6CountLabel = Label(self.sFrame, textvar=self.sensor6CountVar)
        self.sensor7CountLabel = Label(self.sFrame, textvar=self.sensor7CountVar)
        for i in range(0,8):
            eval("self.sensor%dCountLabel.grid(column=%d, row=%d+1)" % (i, 4, i)) 
            
        self.sFrame.grid(column=2, row=1)
        #self.sFrame.grid_propagate(False)

    def enableUI(self):
        self.graph.grid(column=1, row=1)                   
        self.meanLabel.config(state=NORMAL)
        self.stdLabel.config(state=NORMAL)
        self.countLabel.config(state=NORMAL)
        for i in range(0,8):
            eval("self.sensor%dLabel.config(state=NORMAL)" % i) 
            eval("self.sensor%dMeanLabel.config(state=NORMAL)" % i)        
            eval("self.sensor%dStdLabel.config(state=NORMAL)" % i)
            eval("self.sensor%dCountLabel.config(state=NORMAL)" % i)

 
    def disableUI(self):
        self.graph.grid_forget()
        self.meanLabel.config(state=DISABLED)
        self.stdLabel.config(state=DISABLED)
        self.countLabel.config(state=DISABLED)
        for i in range(0,8):
            eval("self.sensor%dLabel.config(state=DISABLED)" % i) 
            eval("self.sensor%dMeanLabel.config(state=DISABLED)" % i)        
            eval("self.sensor%dStdLabel.config(state=DISABLED)" % i)
            eval("self.sensor%dCountLabel.config(state=DISABLED)" % i)

    def connectSignal(self, connected):
        if connected:
            self.enableUI()            
        else:
            self.disableUI()

    def sampleSignal(self, sampling):
        self.sampling = sampling
        if self.sampling:
            self.resetGraph()
            self.graph.after(1000, self.update)


    def resetGraph(self):
        self.allPoints = []
        for i in range(0,8):
            self.mean[i] = 0
            self.count[i] = 0
            self.values[i] = []
            
        self.graph.grid_forget()
        self.graph = self.simplot.makeGraphBase(self, 500, 400, xtitle="Sensor", ytitle="ADC")  

    def update(self):
        try:
            while(True):
                (sensor, adc) = self.handler.getReadings()
                self.allPoints.append((sensor, adc))
                self.mean[sensor] += adc
                self.count[sensor] += 1
                self.values[sensor].append(adc)
        except Queue.Empty:
            pass
        
        self.drawPoints()
        self.calculateStats()
        if self.sampling:
            self.graph.after(1000, self.update)

    def drawPoints(self):    
        #self.graph = self.simplot.makeGraphBase(self, 500, 300, xtitle="Sensor", ytitle="ADC")  
        self.symbols = self.simplot.makeSymbols(self.allPoints, marker="dot", size=1, fillcolor="red")
        self.objects = self.simplot.makeGraphObjects([self.symbols])
        #self.graph.draw(self.objects, xaxis=(0,9), yaxis=(0,4096))
        self.graph.draw(self.objects, xaxis=(0,9), yaxis="automatic")
        self.graph.grid(column=1, row=1)
        #print self.allPoints

    def calculateStats(self):
            
        for i in range(0,8):
            if self.count[i]:
                mean = self.mean[i] / self.count[i]
                std = math.sqrt(sum((x-mean)**2 for x in self.values[i]) / len(self.values[i]))
                eval("self.sensor%dMeanVar.set(%0.1f)" % (i, mean))
                eval("self.sensor%dStdVar.set(%0.1f)" % (i, std))  
                eval("self.sensor%dCountVar.set(%d)" % (i, self.count[i]))  
