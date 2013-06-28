
import Tkinter
from Tkinter import *

from BreakfastError import *
from Toast import Toast


class ToastFrame(Frame):

    def __init__(self, parent, handler, **args):
        Frame.__init__(self, parent, **args)
        
        self.handler = handler
        
        self.assignments = [[0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0]]
        self.sampling = False
        
        self.initUI()
        self.disableUI()
        self.pack()

    def initUI(self):

        #self.adcVar = StringVar()
        #self.adcVar.set("<not available>")
        #self.adcLabel = Label(self, text="ADC:")
        #self.adcLabel.grid(column=1, row=1)
        #self.adcVarLabel = Label(self, textvar=self.adcVar)
        #self.adcVarLabel.grid(column=2, row=1)

        self.currentLabel = Label(self, text="Current Value")
        self.currentLabel.grid(column=2, row=1)
        self.newLabel = Label(self, text="New Value")
        self.newLabel.grid(column=3, row=1, columnspan=2)
    
        self.barcodeLabel = Label(self, text="Toast ID:")
        self.barcodeLabel.grid(column=1, row=2)
        self.barcodeVar = StringVar()
        self.barcodeVar.set("<not available>")
        self.barcodeVarLabel = Label(self, textvar=self.barcodeVar)
        self.barcodeVarLabel.grid(column=2, row=2)
        self.newBarcodeVar = StringVar()
        self.newBarcodeEntry = Entry(self, textvar=self.newBarcodeVar)
        self.newBarcodeEntry.bind("<Return>", self.updateBarcodeKey)
        self.newBarcodeEntry.grid(column=3, row=2, columnspan=2)

        self.dcoLabel = Label(self, text="DCO:")
        self.dcoLabel.grid(column=1, row=3)
        self.dcoVar = StringVar()
        self.dcoVar.set("<not available>")        
        self.dcoVarLabel = Label(self, textvar=self.dcoVar)
        self.dcoVarLabel.grid(column=2, row=3)        
        self.reconnectButton = Button(self, text="Reconnect", command=self.reconnect)
        self.reconnectButton.grid(column=3, row=3) 
        self.newBarcodeButton = Button(self, text="Update", command=self.updateBarcode)
        self.newBarcodeButton.grid(column=4, row=3) 



        self.assignmentVar = StringVar()
        self.assignmentVar.set("<not available>")
        self.assignmentLabel = Label(self, text="Assignments:")
        self.assignmentLabel.grid(column=1, row=4)
        self.assignmentVarLabel = Label(self, textvar=self.assignmentVar)
        self.assignmentVarLabel.grid(column=2, row=4, columnspan=3)
        
        #
        # sensor assignment frame
        #
        self.aFrame = Frame(self, bd=1, relief=SUNKEN)
        
        self.e1Frame = Frame(self.aFrame)
        self.e1Frame.grid(column=1, row=0)
        self.typeLabel = Label(self.aFrame, text="Type")
        self.typeLabel.grid(column=2, row=0)
        self.idLabel = Label(self.aFrame, text="ID")
        self.idLabel.grid(column=3, row=0)
        self.codeLabel = Label(self.aFrame, text="Barcode")
        self.codeLabel.grid(column=4, row=0, columnspan=2)
        
        self.sensor0Label = Label(self.aFrame, text="Sensor 1")
        self.sensor1Label = Label(self.aFrame, text="Sensor 2")
        self.sensor2Label = Label(self.aFrame, text="Sensor 3")
        self.sensor3Label = Label(self.aFrame, text="Sensor 4")
        self.sensor4Label = Label(self.aFrame, text="Sensor 5")
        self.sensor5Label = Label(self.aFrame, text="Sensor 6")
        self.sensor6Label = Label(self.aFrame, text="Sensor 7")
        self.sensor7Label = Label(self.aFrame, text="Sensor 8")
        for i in range(0,8):
            eval("self.sensor%dLabel.grid(column=%d, row=%d+1)" % (i, 1, i))
        
        self.sensor0TypeVar = StringVar()
        self.sensor1TypeVar = StringVar()
        self.sensor2TypeVar = StringVar()
        self.sensor3TypeVar = StringVar()
        self.sensor4TypeVar = StringVar()
        self.sensor5TypeVar = StringVar()
        self.sensor6TypeVar = StringVar()
        self.sensor7TypeVar = StringVar()
        self.sensor0TypeLabel = Label(self.aFrame, textvariable=self.sensor0TypeVar)
        self.sensor1TypeLabel = Label(self.aFrame, textvariable=self.sensor1TypeVar)
        self.sensor2TypeLabel = Label(self.aFrame, textvariable=self.sensor2TypeVar)
        self.sensor3TypeLabel = Label(self.aFrame, textvariable=self.sensor3TypeVar)
        self.sensor4TypeLabel = Label(self.aFrame, textvariable=self.sensor4TypeVar)
        self.sensor5TypeLabel = Label(self.aFrame, textvariable=self.sensor5TypeVar)
        self.sensor6TypeLabel = Label(self.aFrame, textvariable=self.sensor6TypeVar)
        self.sensor7TypeLabel = Label(self.aFrame, textvariable=self.sensor7TypeVar)
        for i in range(0,8):
            eval("self.sensor%dTypeVar.set('N/A')" % i)
            eval("self.sensor%dTypeLabel.grid(column=%d, row=%d+1)" % (i, 2, i))

        self.sensor0IDVar = StringVar()
        self.sensor1IDVar = StringVar()
        self.sensor2IDVar = StringVar()
        self.sensor3IDVar = StringVar()
        self.sensor4IDVar = StringVar()
        self.sensor5IDVar = StringVar()
        self.sensor6IDVar = StringVar()
        self.sensor7IDVar = StringVar()
        self.sensor0IDLabel = Label(self.aFrame, textvariable=self.sensor0IDVar)
        self.sensor1IDLabel = Label(self.aFrame, textvariable=self.sensor1IDVar)
        self.sensor2IDLabel = Label(self.aFrame, textvariable=self.sensor2IDVar)
        self.sensor3IDLabel = Label(self.aFrame, textvariable=self.sensor3IDVar)
        self.sensor4IDLabel = Label(self.aFrame, textvariable=self.sensor4IDVar)
        self.sensor5IDLabel = Label(self.aFrame, textvariable=self.sensor5IDVar)
        self.sensor6IDLabel = Label(self.aFrame, textvariable=self.sensor6IDVar)
        self.sensor7IDLabel = Label(self.aFrame, textvariable=self.sensor7IDVar)
        for i in range(0,8):
            eval("self.sensor%dIDVar.set('N/A')" % i)
            eval("self.sensor%dIDLabel.grid(column=%d, row=%d+1)" % (i, 3, i))


        self.sensor0newIDVar = StringVar()
        self.sensor1newIDVar = StringVar()
        self.sensor2newIDVar = StringVar()
        self.sensor3newIDVar = StringVar()
        self.sensor4newIDVar = StringVar()
        self.sensor5newIDVar = StringVar()
        self.sensor6newIDVar = StringVar()
        self.sensor7newIDVar = StringVar()
        self.sensor0newIDEntry = Entry(self.aFrame, textvariable=self.sensor0newIDVar)
        self.sensor1newIDEntry = Entry(self.aFrame, textvariable=self.sensor1newIDVar)
        self.sensor2newIDEntry = Entry(self.aFrame, textvariable=self.sensor2newIDVar)
        self.sensor3newIDEntry = Entry(self.aFrame, textvariable=self.sensor3newIDVar)
        self.sensor4newIDEntry = Entry(self.aFrame, textvariable=self.sensor4newIDVar)
        self.sensor5newIDEntry = Entry(self.aFrame, textvariable=self.sensor5newIDVar)
        self.sensor6newIDEntry = Entry(self.aFrame, textvariable=self.sensor6newIDVar)
        self.sensor7newIDEntry = Entry(self.aFrame, textvariable=self.sensor7newIDVar)
        for i in range(0,8):
            eval("self.sensor%dnewIDEntry.grid(column=%d, row=%d+1, columnspan=2)" % (i, 4, i))
            eval("self.sensor%dnewIDEntry.bind('<Return>', self.changeFocus)" % i)
        # overwrite the last entries behavior
        self.sensor7newIDEntry.bind('<Return>', self.updateAssignmentsKey)


        self.resetButton = Button(self.aFrame, text="Reset", command=self.reset)
        self.resetButton.grid(column=1, row=10) 

        self.sampleButton = Button(self.aFrame, text="Sample", command=self.sample)
        self.sampleButton.grid(column=4, row=10) 
        
        self.assignButton = Button(self.aFrame, text="Update", command=self.updateAssignments)
        self.assignButton.grid(column=5, row=10)

        self.aFrame.grid(column=1,row=5, columnspan=4)
        



    def enableUI(self):
        #self.adcLabel.config(state=NORMAL)
        #self.adcVarLabel.config(state=NORMAL)
        self.currentLabel.config(state=NORMAL)
        self.newLabel.config(state=NORMAL)
        self.dcoLabel.config(state=NORMAL)
        self.dcoVarLabel.config(state=NORMAL)
        self.reconnectButton.config(state=NORMAL, cursor="hand2")
        self.barcodeLabel.config(state=NORMAL)
        self.barcodeVarLabel.config(state=NORMAL)
        self.newBarcodeEntry.config(state=NORMAL)
        self.newBarcodeButton.config(state=NORMAL, cursor="hand2")
        self.assignmentLabel.config(state=NORMAL)
        self.assignmentVarLabel.config(state=NORMAL)

        # assignment frame
        self.typeLabel.config(state=NORMAL)
        self.idLabel.config(state=NORMAL)
        self.codeLabel.config(state=NORMAL)
        for i in range(0,8):
            eval("self.sensor%dLabel.config(state=NORMAL)" % i) 
            eval("self.sensor%dTypeLabel.config(state=NORMAL)" % i)        
            eval("self.sensor%dIDLabel.config(state=NORMAL)" % i)
            eval("self.sensor%dnewIDEntry.config(state=NORMAL)" % i)
        self.assignButton.config(state=NORMAL, cursor="hand2")
        self.resetButton.config(state=NORMAL, cursor="hand2")
        self.sampleButton.config(state=NORMAL, cursor="hand2")
        
    def disableUI(self):
        #self.adcLabel.config(state=DISABLED)
        #self.adcVarLabel.config(state=DISABLED)
        self.currentLabel.config(state=DISABLED)
        self.newLabel.config(state=DISABLED)
        self.dcoLabel.config(state=DISABLED)
        self.dcoVarLabel.config(state=DISABLED)
        self.reconnectButton.config(state=DISABLED, cursor="")
        self.barcodeLabel.config(state=DISABLED)
        self.barcodeVarLabel.config(state=DISABLED)
        self.newBarcodeEntry.config(state=DISABLED)
        self.newBarcodeButton.config(state=DISABLED, cursor="")
        self.assignmentLabel.config(state=DISABLED)
        self.assignmentVarLabel.config(state=DISABLED)

        # assignment frame
        self.typeLabel.config(state=DISABLED)
        self.idLabel.config(state=DISABLED)
        self.codeLabel.config(state=DISABLED)
        for i in range(0,8):
            eval("self.sensor%dLabel.config(state=DISABLED)" % i) 
            eval("self.sensor%dTypeLabel.config(state=DISABLED)" % i)        
            eval("self.sensor%dIDLabel.config(state=DISABLED)" % i)
            eval("self.sensor%dnewIDEntry.config(state=DISABLED)" % i)
        self.assignButton.config(state=DISABLED, cursor="")
        self.sampleButton.config(state=DISABLED, cursor="")
        self.resetButton.config(state=DISABLED, cursor="")

    def changeFocus(self, event):
        event.widget.tk_focusNext().focus()



    def connectSignal(self, connected):
        if connected:
            self.reconnect()
        else:            
            # if currently sampling, stop sampling
            if self.sampling:
                self.sample()
            
            self.disableUI()

    def reconnect(self):
        self.handler.busy()
        try:
            self.handler.connectToast()
        except:
            self.dcoVar.set("<no device detected>")
            self.assignmentVar.set("<no device detected>")
            self.barcodeVar.set("<no device detected>")

            # disable ToastFrame and GraphFrame UI, keep reconnect button on
            self.disableUI()
            self.reconnectButton.config(state=NORMAL, cursor="hand2")
            
            self.handler.notbusy()
            return
        else:
            self.enableUI()
            self.handler.graphFrame.connectSignal(True)
        
        self.redrawDCO()
        self.redrawBarcode()
        self.redrawAssignments()
        self.handler.notbusy()    

    def reset(self):
        self.handler.busy()
        self.handler.resetToast()
        self.reconnect()

    def sample(self):
        if self.sampling:
            self.sampling = False
            
            self.handler.stopSampling()
            self.enableUI()
            self.sampleButton.config(state=NORMAL, text="Sample", cursor="hand2")
        else:            
            self.sensors = []
            for i in range(0,8):
                if self.assignments[0][i]:
                    self.sensors.append(i)
            
            if self.sensors:
                self.sampling = True
                
                self.disableUI()
                self.sampleButton.config(state=NORMAL, text="Stop", cursor="hand2")
                self.handler.startSampling(self.sensors)


    def redrawDCO(self):
        try:
            dcoStr = self.handler.getDCOSettings()
        except TagNotFoundError:
            self.dcoVar.set("Update DCO")
        except:
            self.dcoVar.set("<DCO error>")
        else:
            self.dcoVar.set(dcoStr)
    

    def redrawBarcode(self):
        try:
            barcodeStr = self.handler.getToastBarcode()
        except TagNotFoundError:
            self.barcodeVar.set("<no assignemnts set>")
            self.barcodeVarLabel.config(fg="black")
            self.newBarcodeEntry.focus_set()
        except Exception:
            self.barcodeVar.set("<read error>")
            self.barcodeVarLabel.config(fg="red")
        else:
            self.barcodeVar.set(barcodeStr)
            self.barcodeVarLabel.config(fg="black")

    def updateBarcodeKey(self, event):
        self.updateBarcode()
        self.sensor0newTypeEntry.focus()

    def updateBarcode(self):
        try:
            self.handler.setToastBarcode(self.newBarcodeVar.get())
            barcodeStr = self.handler.getToastBarcode()
        except ValueError:
            self.barcodeVar.set("<barcode not an integer>")
            self.barcodeVarLabel.config(fg="red")
        except:
            self.barcodeVar.set("<update failed>")
            self.barcodeVarLabel.config(fg="red")
        else:    
            self.newBarcodeVar.set("")
            self.redrawBarcode()



    def redrawAssignments(self):

        try:
            self.assignments = self.handler.getAssignments()
        except TagNotFoundError:
            self.assignmentVar.set("<no assignemnts set>")
            self.assignments = Toast.EMPTY_ASSIGNMENTS
        except Exception:
            self.assignmentVar.set("<read error>")
            self.assignmentVarLabel.config(fg="red")
            self.assignments = Toast.EMPTY_ASSIGNMENTS
        else:
            self.assignmentVar.set("")
            self.assignmentVarLabel.config(fg="black")
        finally:
            for i in range(0,8):        
                tmpID = self.assignments[0][i]
                if tmpID:
                    tmpStr = "%02X%02X" % ((tmpID >> 8) & 0xFF, tmpID & 0xFF)
                    tmpType = "%02X" % self.assignments[1][i]
                else:
                    tmpStr = "N/A"
                    tmpType = "N/A"

                eval("self.sensor%dIDVar.set(tmpStr)" % (i))
                eval("self.sensor%dTypeVar.set(tmpType)" % (i))


    def updateAssignmentsKey(self, event):
        self.updateAssignments()

    def updateAssignments(self):
        self.assignmentVar.set("")
        change = False
        for i in range(0,8):
            newID = self.assignments[0][i]
            newType = self.assignments[1][i]
            
            setattr(self, "code", eval("self.sensor%dnewIDVar.get()" % i))
            
            if self.code != "":
                try:
                    tmp = int(self.code, 16)
                    newID = tmp & 0xFFFF
                    newType = (tmp >> 16) & 0xFF
                except:
                    self.assignmentVar.set("<invalid input>")
                    self.assignmentVarLabel.config(fg="red")
                    return
                
                if self.assignments[0][i] != newID:
                    self.assignments[0][i] = newID
                    change = True
                    
                if self.assignments[1][i] != newType:
                    self.assignments[1][i] = newType
                    change = True
            
        if change:
            print self.assignments
            try:
                self.handler.setAssignments(self.assignments)
            except OutOfSpaceError:
                self.assignmentVar.set("Out of memory")
            except UnexpectedResponseError:
                self.assignmentVar.set("Update Failed")
            else:
                for i in range(0,8):
                    eval("self.sensor%dnewIDVar.set('')" % i)
                self.redrawAssignments()


