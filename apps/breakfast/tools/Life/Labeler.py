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

def xscrollSet(lo, hi):
    if float(lo) <= 0.0 and float(hi) >= 1.0:
        # grid_remove is currently missing from Tkinter!
        xscrollbar.tk.call("grid", "remove", xscrollbar)
        xscrollOn = False
    else:
        xscrollbar.grid()
        xscrollOn = True
    xscrollbar.set(lo, hi)        
    
def yscrollSet(lo, hi):
    if float(lo) <= 0.0 and float(hi) >= 1.0:
        # grid_remove is currently missing from Tkinter!
        yscrollbar.tk.call("grid", "remove", yscrollbar)
        yscrollOn = False
    else:
        yscrollbar.grid()
        yscrollOn = True
    yscrollbar.set(lo, hi)        

def updateCanvas(event):        
    canvas.configure(scrollregion=canvas.bbox("all"))
    
simplot = SimPlot()
root = simplot.root
#root = Tk()

handler = Handler(root)    

WIDTH = 1280
HEIGHT = 630
MAIN = 400

root.geometry(str(WIDTH) + "x" + str(HEIGHT))
root.title("Labeler")
root.bind_class("Entry","<Control-a>", selectall)
root.bind("<Alt-F4>", quit)
root.bind('<Control-c>', quit)
root.protocol("WM_DELETE_WINDOW", quit)


#
# scroll bars
#
xscrollOn = False
yscrollOn = False

xscrollbar = Scrollbar(root, orient=HORIZONTAL)
xscrollbar.grid(column=0, row=1, sticky=E+W)
yscrollbar = Scrollbar(root)
yscrollbar.grid(column=1, row=0, sticky=N+S)

canvas = Canvas(root, yscrollcommand=yscrollSet, xscrollcommand=xscrollSet)
canvas.grid(row=0, column=0, sticky=N+S+E+W)

yscrollbar.config(command=canvas.yview)
xscrollbar.config(command=canvas.xview)

# make the canvas expandable
root.grid_rowconfigure(0, weight=1)
root.grid_columnconfigure(0, weight=1)

rootFrame = Frame(canvas)
rootFrame.rowconfigure(1, weight=1)
rootFrame.columnconfigure(1, weight=1)
canvas.create_window(0, 0, anchor=NW, window=rootFrame)

rootFrame.bind("<Configure>", updateCanvas)

#
# Frames on top of canvas
#
menuFrame = MenuFrame(rootFrame, handler, width=WIDTH-4, height=40, bd=1, relief=SUNKEN)
menuFrame.grid_propagate(False)
menuFrame.grid(column=1, row=1, columnspan=2)
handler.addMenuFrame(menuFrame)

baconFrame = BaconFrame(rootFrame, handler, width=MAIN, height=90, bd=1, relief=SUNKEN)
baconFrame.grid_propagate(False)
baconFrame.grid(column=1, row=2)
handler.addBaconFrame(baconFrame)

toastFrame = ToastFrame(rootFrame, handler, width=MAIN, height=385, bd=1, relief=SUNKEN)
toastFrame.grid_propagate(False)
toastFrame.grid(column=1, row=3)
handler.addToastFrame(toastFrame)

graphFrame = GraphFrame(rootFrame, handler, simplot, width=WIDTH-MAIN-4, height=475, bd=1, relief=SUNKEN)
graphFrame.grid_propagate(False)
graphFrame.grid(column=2, row=2, rowspan=2)
handler.addGraphFrame(graphFrame)

adcFrame = AdcFrame(rootFrame, handler, width=WIDTH-4, height=90, bd=1, relief=SUNKEN)
adcFrame.grid_propagate(False)
adcFrame.grid(column=1, row=4, columnspan=2)
handler.addAdcFrame(adcFrame)

#menuFrame = Frame(rootFrame, width=1024, height=30, bd=1, relief=SUNKEN)
#menuFrame.grid(column=1, row=4, columnspan=2)

try:
    root.mainloop()
except KeyboardInterrupt:
    pass
