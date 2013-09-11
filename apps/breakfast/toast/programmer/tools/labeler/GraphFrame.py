
import math
import Queue
import Tkinter
import tkMessageBox
from Tkinter import *

from tools.labeler.BreakfastError import *
from tools.SimPy.SimPlot import * 

HEIGHT = 480

class GraphFrame(Frame):

    def __init__(self, parent, handler, simplot, **args):
        Frame.__init__(self, parent, **args)
        
        self.parent = parent
        self.handler = handler
        self.simplot = simplot
        self.allPoints = []
        self.meanPoints = []
        self.graph = None
        
        self.mean = [0,0,0,0,0,0,0,0]
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
        
        self.sFrame = Frame(self, width=230, height=HEIGHT)
        self.meanLabel = Label(self.sFrame, text="Mean", width=5, padx=5)
        self.meanLabel.grid(column=2, row=0)
        self.stdLabel = Label(self.sFrame, text="Std", width=4)
        self.stdLabel.grid(column=3, row=0)
        self.countLabel = Label(self.sFrame, text="Count")
        self.countLabel.grid(column=4, row=0)
        
        self.sensor0Label = Label(self.sFrame, text="Channel 1", width=9)
        self.sensor1Label = Label(self.sFrame, text="Channel 2")
        self.sensor2Label = Label(self.sFrame, text="Channel 3")
        self.sensor3Label = Label(self.sFrame, text="Channel 4")
        self.sensor4Label = Label(self.sFrame, text="Channel 5")
        self.sensor5Label = Label(self.sFrame, text="Channel 6")
        self.sensor6Label = Label(self.sFrame, text="Channel 7")
        self.sensor7Label = Label(self.sFrame, text="Channel 8")
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
        self.sensor0MeanLabel = Label(self.sFrame, textvar=self.sensor0MeanVar, padx=5, anchor=E, width=5)
        self.sensor1MeanLabel = Label(self.sFrame, textvar=self.sensor1MeanVar, padx=5, anchor=E, width=5)
        self.sensor2MeanLabel = Label(self.sFrame, textvar=self.sensor2MeanVar, padx=5, anchor=E, width=5)
        self.sensor3MeanLabel = Label(self.sFrame, textvar=self.sensor3MeanVar, padx=5, anchor=E, width=5)
        self.sensor4MeanLabel = Label(self.sFrame, textvar=self.sensor4MeanVar, padx=5, anchor=E, width=5)
        self.sensor5MeanLabel = Label(self.sFrame, textvar=self.sensor5MeanVar, padx=5, anchor=E, width=5)
        self.sensor6MeanLabel = Label(self.sFrame, textvar=self.sensor6MeanVar, padx=5, anchor=E, width=5)
        self.sensor7MeanLabel = Label(self.sFrame, textvar=self.sensor7MeanVar, padx=5, anchor=E, width=5)
        for i in range(0,8):
            eval("self.sensor%dMeanLabel.grid(column=%d, row=%d+1, sticky=E)" % (i, 2, i))            

        self.sensor0StdVar = DoubleVar()
        self.sensor1StdVar = DoubleVar()
        self.sensor2StdVar = DoubleVar()
        self.sensor3StdVar = DoubleVar()
        self.sensor4StdVar = DoubleVar()
        self.sensor5StdVar = DoubleVar()
        self.sensor6StdVar = DoubleVar()
        self.sensor7StdVar = DoubleVar()
        self.sensor0StdLabel = Label(self.sFrame, textvar=self.sensor0StdVar, anchor=E, width=4)
        self.sensor1StdLabel = Label(self.sFrame, textvar=self.sensor1StdVar, anchor=E, width=4)
        self.sensor2StdLabel = Label(self.sFrame, textvar=self.sensor2StdVar, anchor=E, width=4)
        self.sensor3StdLabel = Label(self.sFrame, textvar=self.sensor3StdVar, anchor=E, width=4)
        self.sensor4StdLabel = Label(self.sFrame, textvar=self.sensor4StdVar, anchor=E, width=4)
        self.sensor5StdLabel = Label(self.sFrame, textvar=self.sensor5StdVar, anchor=E, width=4)
        self.sensor6StdLabel = Label(self.sFrame, textvar=self.sensor6StdVar, anchor=E, width=4)
        self.sensor7StdLabel = Label(self.sFrame, textvar=self.sensor7StdVar, anchor=E, width=4)
        for i in range(0,8):
            eval("self.sensor%dStdLabel.grid(column=%d, row=%d+1, sticky=E)" % (i, 3, i))            

        self.sensor0CountVar = IntVar()
        self.sensor1CountVar = IntVar()
        self.sensor2CountVar = IntVar()
        self.sensor3CountVar = IntVar()
        self.sensor4CountVar = IntVar()
        self.sensor5CountVar = IntVar()
        self.sensor6CountVar = IntVar()
        self.sensor7CountVar = IntVar()
        self.sensor0CountLabel = Label(self.sFrame, textvar=self.sensor0CountVar, anchor=E, width=4)
        self.sensor1CountLabel = Label(self.sFrame, textvar=self.sensor1CountVar, anchor=E, width=4)
        self.sensor2CountLabel = Label(self.sFrame, textvar=self.sensor2CountVar, anchor=E, width=4)
        self.sensor3CountLabel = Label(self.sFrame, textvar=self.sensor3CountVar, anchor=E, width=4)
        self.sensor4CountLabel = Label(self.sFrame, textvar=self.sensor4CountVar, anchor=E, width=4)
        self.sensor5CountLabel = Label(self.sFrame, textvar=self.sensor5CountVar, anchor=E, width=4)
        self.sensor6CountLabel = Label(self.sFrame, textvar=self.sensor6CountVar, anchor=E, width=4)
        self.sensor7CountLabel = Label(self.sFrame, textvar=self.sensor7CountVar, anchor=E, width=4)
        for i in range(0,8):
            eval("self.sensor%dCountLabel.grid(column=%d, row=%d+1)" % (i, 4, i)) 
            
        
        self.sampleButton = Button(self.sFrame, text="Start sampling", command=self.sample, width=15)
        self.sampleButton.grid(column=1, row=9, columnspan=4) 
        
        self.sFrame.grid(column=2, row=1)
        self.sFrame.grid_propagate(False)

    def enableUI(self):
        self.initGraph()
        self.resetStat()
        #self.graph.grid(column=1, row=1)                   
        self.meanLabel.config(state=NORMAL)
        self.stdLabel.config(state=NORMAL)
        self.countLabel.config(state=NORMAL)
        for i in range(0,8):
            eval("self.sensor%dLabel.config(state=NORMAL)" % i) 
            eval("self.sensor%dMeanLabel.config(state=NORMAL)" % i)        
            eval("self.sensor%dStdLabel.config(state=NORMAL)" % i)
            eval("self.sensor%dCountLabel.config(state=NORMAL)" % i)
        self.sampleButton.config(state=NORMAL, cursor="hand2")

 
    def disableUI(self):
        self.graph.grid_forget()
        self.resetStat()
        self.meanLabel.config(state=DISABLED)
        self.stdLabel.config(state=DISABLED)
        self.countLabel.config(state=DISABLED)
        for i in range(0,8):
            eval("self.sensor%dLabel.config(state=DISABLED)" % i) 
            eval("self.sensor%dMeanLabel.config(state=DISABLED)" % i)        
            eval("self.sensor%dStdLabel.config(state=DISABLED)" % i)
            eval("self.sensor%dCountLabel.config(state=DISABLED)" % i)
        self.sampleButton.config(state=DISABLED, cursor="")

    def connectSignal(self, connected):
        if connected:
            self.enableUI()            
        else:
            # if currently sampling, stop sampling
            if self.sampling:
                self.sample()
            
            self.disableUI()



    def initGraph(self):
        if self.graph:
            self.graph.grid_forget()
        
        bgcolor = self.cget('bg')
        
        self.gFrame = Frame(self, width=650, height=HEIGHT)
        self.graph = self.simplot.makeGraphBase(self.gFrame, 650, HEIGHT, xtitle="Sensor", ytitle="ADC", background=bgcolor)  
        self.sym = self.simplot.makeSymbols([[0,0]], marker="dot", size=1, fillcolor="red")
        self.obj = self.simplot.makeGraphObjects([self.sym])
        self.graph.draw(self.obj, xaxis=(0,9), yaxis=(0,4096))
        self.graph.grid(column=1, row=1)

        self.gFrame.grid_propagate(False)
        self.gFrame.grid(column=1, row=1)

    def resetGraph(self):
        oldGraph = self.graph
        self.graph = self.simplot.makeGraphBase(self.gFrame, 650, HEIGHT, xtitle="Sensor", ytitle="ADC")  
        self.graph.grid(column=1, row=1)
        oldGraph.grid_forget()
    
    def resetStat(self):
        self.allPoints = []
        for i in range(0,8):
            self.mean[i] = 0
            self.count[i] = 0
            self.values[i] = []
            
            eval("self.sensor%dMeanVar.set(0.0)" % i)
            eval("self.sensor%dStdVar.set(0.0)" % i) 
            eval("self.sensor%dCountVar.set(0)" % i) 

    #
    # Graph and stat update
    #    
    def sample(self):
        if self.sampling:
            self.sampling = False
            
            self.handler.stopSampling()
            #self.enableUI()
            self.sampleButton.config(state=NORMAL, text="Start sampling", cursor="hand2")
        else:            
            self.sensors = []
            for i in range(0,8):
                # removed step to only sample channels with sensors assigned
                #if self.handler.toastFrame.assignments[0][i]:
                self.sensors.append(i)
            
            if self.sensors:
                self.sampling = True
                
                #self.disableUI()
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

    def update(self):
        if self.sampling:
            try:
                while(True):
                    (sensor, adc) = self.handler.getReadings()
                    self.allPoints.append((sensor, adc))
                    
                    # sensors are labeled 1-8
                    self.mean[sensor-1] += adc
                    self.count[sensor-1] += 1
                    self.values[sensor-1].append(adc)
            except Queue.Empty:
                pass
            
            self.calculateStats()
            self.drawPoints()
            self.graph.after(1000, self.update)

    def drawPoints(self):    
        #self.graph = self.simplot.makeGraphBase(self, HEIGHT, 300, xtitle="Sensor", ytitle="ADC")  
        #self.resetGraph()
        self.graph.clear()
        self.symbols = self.simplot.makeSymbols(self.allPoints, marker="dot", size=1, fillcolor="red")
        self.means = self.simplot.makeSymbols(self.meanPoints, marker="circle", size=1.5, fillcolor="green")
        self.objects = self.simplot.makeGraphObjects([self.symbols, self.means])
        #self.graph.draw(self.objects, xaxis=(0,9), yaxis=(0,4096))
        self.graph.draw(self.objects, xaxis=(0,9), yaxis="automatic")
 
        #print self.allPoints

    def calculateStats(self):
        self.meanPoints = []
        for i in range(0,8):
            if self.count[i]:
                mean = self.mean[i] / self.count[i]
                std = math.sqrt(sum((x-mean)**2 for x in self.values[i]) / len(self.values[i]))
                eval("self.sensor%dMeanVar.set(%0.1f)" % (i, mean))
                eval("self.sensor%dStdVar.set(%0.1f)" % (i, std))  
                eval("self.sensor%dCountVar.set(%d)" % (i, self.count[i]))  
                self.meanPoints.append((i+1, mean))
