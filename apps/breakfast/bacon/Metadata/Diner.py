#!/usr/bin/env python

from Tkinter import *

from ComSelectorFrame import ComSelectorFrame
from BaconFrame import BaconFrame
from ToastFrame import ToastFrame
from Handler import Handler



root = Tk()

handler = Handler()    

root.geometry("1024x768")

comFrame = ComSelectorFrame(root, handler, width=1024, height=68, bd=1, relief=SUNKEN)
comFrame.grid(column=1, row=1, columnspan=2)


baconFrame = BaconFrame(root, handler, width=500, height=700, bd=1, relief=SUNKEN)
baconFrame.grid(column=1, row=2)

toastFrame = ToastFrame(root, handler, width=524, height=700, bd=1, relief=SUNKEN)
toastFrame.grid(column=2, row=2)

menuFrame = Frame(root, width=1024, height=30, bd=1, relief=SUNKEN)
menuFrame.grid(column=1, row=3, columnspan=2)


root.mainloop()

