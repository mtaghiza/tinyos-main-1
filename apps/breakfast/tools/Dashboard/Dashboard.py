#!/usr/bin/env python

import Tkinter
import tkMessageBox

#from toaster.MenuFrame import MenuFrame
#from toaster.BaconFrame import BaconFrame
#from toaster.ToastFrame import ToastFrame
#from toaster.GraphFrame import GraphFrame
#from toaster.AdcFrame import AdcFrame
#from dashboard.Handler import Handler
#from dashboard.ScrolledList import ScrolledList

from SimPy.SimPlot import * 
#from AutoScrollbar import AutoScrollbar
from dashboard.ScrollFrame import ScrollFrame
from dashboard.ControlFrame import ControlFrame
from dashboard.DisplayFrame import DisplayFrame
from dashboard.Hub import Hub

def selectall(event):
    event.widget.select_range(0, END)

def quit():
    root.quit()


simplot = SimPlot()
root = simplot.root

hub = Hub()    

width = 1280
height = 630

root.geometry("1280x630")
root.title("Dashboard")
root.bind_class("Entry","<Control-a>", selectall)
root.protocol("WM_DELETE_WINDOW", quit)

topFrame = ControlFrame(root, hub, width=1280, height=40, bd=1, relief=SUNKEN)
topFrame.grid_propagate(False)
topFrame.grid(column=1, row=1, columnspan=2)
hub.addControlFrame(topFrame)

scrollFrame = ScrollFrame(root, hub, width=860, height=500, bd=1, relief=SUNKEN)
scrollFrame.grid_propagate(False)
scrollFrame.grid(column=1, row=2)
hub.addNodeFrame(scrollFrame.frame)

displayFrame = DisplayFrame(root, hub, width=420, height=500, bd=1, relief=SUNKEN)
displayFrame.grid_propagate(False)
displayFrame.grid(column=2, row=2)
hub.addDisplayFrame(displayFrame)

statusFrame = Frame(root, width=1280, height=40, bd=1, relief=SUNKEN)
statusFrame.grid_propagate(False)
statusFrame.grid(column=1, row=3, columnspan=2)
hub.addStatusFrame(statusFrame)

#
# create canvas contents



root.mainloop()

