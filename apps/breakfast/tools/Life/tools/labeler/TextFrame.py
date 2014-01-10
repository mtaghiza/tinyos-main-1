import Tkinter
from Tkinter import *

from tools.labeler.BreakfastError import *

class TextFrame(Frame):

    TYPE_TOAST = 0x05
    TYPE_MINITOAST = 0x06


    def __init__(self, parent, handler, **args):
        Frame.__init__(self, parent, **args)
        
        self.handler = handler
        self.initUI()
        self.enableUI()
        self.pack()

    def initUI(self):
        self.msgVar = StringVar()
        self.msgVar.set("hello")
        self.msgLabel = Label(self, textvariable=self.handler.dbgVar, bg="#EEEEEE")
        self.msgLabel.grid(column=1, row=1)

    def enableUI(self):
        self.msgLabel.config(state=NORMAL)

    def disableUI(self):
        self.msgLabel.config(state=DISABLED)

    def connectSignal(self, connected):
        if connected:
            self.enableUI()
        else:
            self.disableUI()
            
