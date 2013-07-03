#!/usr/bin/env python

from Tkinter import *

from ComSelectorFrame import ComSelectorFrame
from BaconFrame import BaconFrame
from ToastFrame import ToastFrame
from Handler import Handler
from GraphFrame import GraphFrame
from AdcFrame import AdcFrame

from SimPy.SimPlot import * 

def selectall(event):
    event.widget.select_range(0, END)


simplot = SimPlot()
root = simplot.root
#root = Tk()

handler = Handler(root)    

root.geometry("1280x720")
root.title("Toaster")
root.bind_class("Entry","<Control-a>", selectall)

comFrame = ComSelectorFrame(root, handler, width=1280, height=40, bd=1, relief=SUNKEN)
comFrame.grid_propagate(False)
comFrame.grid(column=1, row=1, columnspan=2)
handler.addComFrame(comFrame)

baconFrame = BaconFrame(root, handler, width=420, height=100, bd=1, relief=SUNKEN)
baconFrame.grid_propagate(False)
baconFrame.grid(column=1, row=2)
handler.addBaconFrame(baconFrame)

toastFrame = ToastFrame(root, handler, width=420, height=400, bd=1, relief=SUNKEN)
toastFrame.grid_propagate(False)
toastFrame.grid(column=1, row=3)
handler.addToastFrame(toastFrame)

graphFrame = GraphFrame(root, handler, simplot, width=860, height=500, bd=1, relief=SUNKEN)
graphFrame.grid_propagate(False)
graphFrame.grid(column=2, row=2, rowspan=2)
handler.addGraphFrame(graphFrame)

adcFrame = AdcFrame(root, handler, width=1280, height=60, bd=1, relief=SUNKEN)
adcFrame.grid_propagate(False)
adcFrame.grid(column=1, row=4, columnspan=2)
handler.addAdcFrame(adcFrame)

#menuFrame = Frame(root, width=1024, height=30, bd=1, relief=SUNKEN)
#menuFrame.grid(column=1, row=4, columnspan=2)


root.mainloop()

