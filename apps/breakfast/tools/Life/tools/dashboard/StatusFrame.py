import Tkinter
from Tkinter import *

class StatusFrame(Frame):
    SPACING = 10
    def __init__(self, parent, hub, **args):
        Frame.__init__(self, parent, **args)
        self.hub = hub
        self.initUI()

    def initUI(self):
        self.messageFrame = Frame(self, padx=self.SPACING)
        self.messageText = Text(self.messageFrame, height=10,
          width=50, background='white')
        scroll = Scrollbar(self.messageFrame)
        self.messageText.configure(yscrollcommand=scroll.set)

        self.messageText.pack(side=LEFT)
        scroll.pack(side=RIGHT, fill=Y)
        self.messageFrame.pack(side=TOP)

    def addMessage(self, msg):
        print "addMessage", msg
        self.messageText.insert(END, msg)
        #TODO: append to text box widget contents
        pass
