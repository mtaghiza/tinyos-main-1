#!/usr/bin/env python

from Tkinter import *

from tools.labeler.MenuFrame import MenuFrame
from tools.labeler.BaconFrame import BaconFrame
from tools.labeler.ToastFrame import ToastFrame
from tools.labeler.Handler import Handler
from tools.labeler.GraphFrame import GraphFrame
from tools.labeler.AdcFrame import AdcFrame

from tools.SimPy.SimPlot import SimPlot 

def selectall(event):
    event.widget.select_range(0, END)

def quit(key=None):
    handler.menuFrame.disconnect()
    root.quit()

simplot = SimPlot()
root = simplot.root
#root = Tk()

handler = Handler(root)    

root.geometry("1280x630")
root.title("Labeler")
root.bind_class("Entry","<Control-a>", selectall)
root.bind("<Alt-F4>", quit)
root.bind('<Control-c>', quit)
root.protocol("WM_DELETE_WINDOW", quit)
root.resizable(0,0)

menuFrame = MenuFrame(root, handler, width=1280, height=40, bd=1, relief=SUNKEN)
menuFrame.grid_propagate(False)
menuFrame.grid(column=1, row=1, columnspan=2)
handler.addMenuFrame(menuFrame)

baconFrame = BaconFrame(root, handler, width=400, height=100, bd=1, relief=SUNKEN)
baconFrame.grid_propagate(False)
baconFrame.grid(column=1, row=2)
handler.addBaconFrame(baconFrame)

toastFrame = ToastFrame(root, handler, width=400, height=400, bd=1, relief=SUNKEN)
toastFrame.grid_propagate(False)
toastFrame.grid(column=1, row=3)
handler.addToastFrame(toastFrame)

graphFrame = GraphFrame(root, handler, simplot, width=880, height=500, bd=1, relief=SUNKEN)
graphFrame.grid_propagate(False)
graphFrame.grid(column=2, row=2, rowspan=2)
handler.addGraphFrame(graphFrame)

adcFrame = AdcFrame(root, handler, width=1280, height=90, bd=1, relief=SUNKEN)
adcFrame.grid_propagate(False)
adcFrame.grid(column=1, row=4, columnspan=2)
handler.addAdcFrame(adcFrame)

#menuFrame = Frame(root, width=1024, height=30, bd=1, relief=SUNKEN)
#menuFrame.grid(column=1, row=4, columnspan=2)

try:
    root.mainloop()
except KeyboardInterrupt:
    pass
