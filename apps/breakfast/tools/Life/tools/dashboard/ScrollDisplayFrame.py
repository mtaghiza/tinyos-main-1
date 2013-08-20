from Tkinter import *
from sys import platform as _platform

from tools.dashboard.DisplayFrame import DisplayFrame as ContentFrame


class ScrollDisplayFrame(Frame):

    def __init__(self, parent, hub, **args):
        Frame.__init__(self, parent, **args)
        
        self.parent = parent
        self.hub = hub
        
        self.xscrollOn = False
        self.yscrollOn = False
        
        self.initUI()  
    
    def initUI(self):                
        self.xscrollbar = Scrollbar(self, orient=HORIZONTAL)
        self.xscrollbar.grid(column=0, row=1, sticky=E+W)
        self.yscrollbar = Scrollbar(self)
        self.yscrollbar.grid(column=1, row=0, sticky=N+S)

        self.canvas = Canvas(self, yscrollcommand=self.yscrollSet, xscrollcommand=self.xscrollSet)
        self.canvas.grid(row=0, column=0, sticky=N+S+E+W)

        self.yscrollbar.config(command=self.canvas.yview)
        self.xscrollbar.config(command=self.canvas.xview)

        # make the canvas expandable
        self.grid_rowconfigure(0, weight=1)
        self.grid_columnconfigure(0, weight=1)

        self.frame = ContentFrame(self.canvas, self.hub)
        self.frame.rowconfigure(1, weight=1)
        self.frame.columnconfigure(1, weight=1)
        self.canvas.create_window(0, 0, anchor=NW, window=self.frame)
        
        self.frame.bind("<Configure>", self.updateCanvas)
        
        # scroll wheel
        #if _platform == "linux" or _platform == "linux2":
        #    self.canvas.bind("<Button-4>", self.mouseUp)
        #    self.canvas.bind("<Button-5>", self.mouseDown)
        #elif _platform == "win32":
        #    self.canvas.bind("<MouseWheel>", self.mouseWheel)
        #elif _platform == "darwin":
        #    print "Note: mouse wheel not implemented on Mac OS"

    #
    # scroll wheel
    #
    def mouseUp(self, event):
        if self.yscrollOn:
            self.canvas.yview_scroll(-1, "units")

    def mouseDown(self, event):
        if self.yscrollOn:
            self.canvas.yview_scroll(1, "units")

    def mouseWheel(self, event):
        if self.yscrollOn:
            self.canvas.yview_scroll(-1*(event.delta/120), "units")

    def xscrollSet(self, lo, hi):
        if float(lo) <= 0.0 and float(hi) >= 1.0:
            # grid_remove is currently missing from Tkinter!
            self.xscrollbar.tk.call("grid", "remove", self.xscrollbar)
            self.xscrollOn = False
        else:
            self.xscrollbar.grid()
            self.xscrollOn = True
        self.xscrollbar.set(lo, hi)        
        
    def yscrollSet(self, lo, hi):
        if float(lo) <= 0.0 and float(hi) >= 1.0:
            # grid_remove is currently missing from Tkinter!
            self.yscrollbar.tk.call("grid", "remove", self.yscrollbar)
            self.yscrollOn = False
        else:
            self.yscrollbar.grid()
            self.yscrollOn = True
        self.yscrollbar.set(lo, hi)        

    def updateCanvas(self, event):        
        self.canvas.configure(scrollregion=self.canvas.bbox("all"))


