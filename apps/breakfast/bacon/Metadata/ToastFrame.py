
import Tkinter
from Tkinter import *

from BreakfastError import *
from Toast import Toast


class ToastFrame(Frame):

    def __init__(self, parent, handler, **args):
        Frame.__init__(self, parent, **args)
        
        self.handler = handler
        self.handler.addConnectListener(self.connectSignal)
        
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

        self.dcoVar = StringVar()
        self.dcoVar.set("<not available>")        
        self.dcoLabel = Label(self, text="DCO:")
        self.dcoLabel.grid(column=1, row=1)
        self.dcoVarLabel = Label(self, textvar=self.dcoVar)
        self.dcoVarLabel.grid(column=2, row=1)

        self.reconnectButton = Button(self, text="Reconnect", command=self.reconnect)
        self.reconnectButton.grid(column=4, row=1) 
    
        self.barcodeVar = StringVar()
        self.barcodeVar.set("<not available>")
        self.barcodeLabel = Label(self, text="Toast ID:")
        self.barcodeLabel.grid(column=1, row=3)
        self.barcodeVarLabel = Label(self, textvar=self.barcodeVar)
        self.barcodeVarLabel.grid(column=2, row=3)
        self.newBarcodeVar = StringVar()
        self.newBarcodeEntry = Entry(self, textvar=self.newBarcodeVar)
        self.newBarcodeEntry.grid(column=3, row=3)
        self.newBarcodeEntry.bind("<Return>", self.updateBarcodeKey)
        self.newBarcodeButton = Button(self, text="Update", command=self.updateBarcode)
        self.newBarcodeButton.grid(column=4, row=3) 


        self.assignmentVar = StringVar()
        self.assignmentVar.set("<not available>")
        self.assignmentLabel = Label(self, text="Assignments:")
        self.assignmentLabel.grid(column=1, row=4)
        self.assignmentVarLabel = Label(self, textvar=self.assignmentVar)
        self.assignmentVarLabel.grid(column=2, row=4, columnspan=3)
        
        
        self.aFrame = Frame(self, bd=1, relief=SUNKEN)
        
        self.e1Frame = Frame(self.aFrame)
        self.e1Frame.grid(column=1, row=0, columnspan=4)
        self.typeLabel = Label(self.aFrame, text="New Type")
        self.typeLabel.grid(column=5, row=0)
        self.IDLabel = Label(self.aFrame, text="New ID")
        self.IDLabel.grid(column=6, row=0)
        
        
        self.sensor0Label = Label(self.aFrame, text="Sensor 1")
        self.sensor1Label = Label(self.aFrame, text="Sensor 2")
        self.sensor2Label = Label(self.aFrame, text="Sensor 3")
        self.sensor3Label = Label(self.aFrame, text="Sensor 4")
        self.sensor4Label = Label(self.aFrame, text="Sensor 5")
        self.sensor5Label = Label(self.aFrame, text="Sensor 6")
        self.sensor6Label = Label(self.aFrame, text="Sensor 7")
        self.sensor7Label = Label(self.aFrame, text="Sensor 8")
        for i in range(0,8):
            eval("self.sensor%dLabel.grid(column=%d, row=%d+1)" % (i, 2, i))

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
            eval("self.sensor%dTypeLabel.grid(column=%d, row=%d+1)" % (i, 3, i))

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
            eval("self.sensor%dIDLabel.grid(column=%d, row=%d+1)" % (i, 4, i))

        self.sensor0newTypeVar = StringVar()
        self.sensor1newTypeVar = StringVar()
        self.sensor2newTypeVar = StringVar()
        self.sensor3newTypeVar = StringVar()
        self.sensor4newTypeVar = StringVar()
        self.sensor5newTypeVar = StringVar()
        self.sensor6newTypeVar = StringVar()
        self.sensor7newTypeVar = StringVar()
        self.sensor0newTypeEntry = Entry(self.aFrame, textvariable=self.sensor0newTypeVar)
        self.sensor1newTypeEntry = Entry(self.aFrame, textvariable=self.sensor1newTypeVar)
        self.sensor2newTypeEntry = Entry(self.aFrame, textvariable=self.sensor2newTypeVar)
        self.sensor3newTypeEntry = Entry(self.aFrame, textvariable=self.sensor3newTypeVar)
        self.sensor4newTypeEntry = Entry(self.aFrame, textvariable=self.sensor4newTypeVar)
        self.sensor5newTypeEntry = Entry(self.aFrame, textvariable=self.sensor5newTypeVar)
        self.sensor6newTypeEntry = Entry(self.aFrame, textvariable=self.sensor6newTypeVar)
        self.sensor7newTypeEntry = Entry(self.aFrame, textvariable=self.sensor7newTypeVar)

        for i in range(0,8):
            eval("self.sensor%dnewTypeEntry.grid(column=%d, row=%d+1)" % (i, 5, i))
            eval("self.sensor%dnewTypeEntry.bind('<Return>', self.changeFocus)" % i)


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
            eval("self.sensor%dnewIDEntry.grid(column=%d, row=%d+1)" % (i, 6, i))
            eval("self.sensor%dnewIDEntry.bind('<Return>', self.changeFocus)" % i)
        # overwrite the last entries behavior
        self.sensor7newIDEntry.bind('<Return>', self.updateAssignmentsKey)


        self.e2Frame = Frame(self.aFrame)
        self.e2Frame.grid(column=1, row=1, columnspan=5)
        
        self.resetButton = Button(self.aFrame, text="Reset", command=self.reset)
        self.resetButton.grid(column=4, row=10) 

        self.sampleButton = Button(self.aFrame, text="Sample", command=self.sample)
        self.sampleButton.grid(column=5, row=10) 
        
        self.assignButton = Button(self.aFrame, text="Update", command=self.updateAssignments)
        self.assignButton.grid(column=6, row=10)

        self.aFrame.grid(column=1,row=5, columnspan=4)
        



    def enableUI(self):
        #self.adcLabel.config(state=NORMAL)
        #self.adcVarLabel.config(state=NORMAL)
        self.dcoLabel.config(state=NORMAL)
        self.dcoVarLabel.config(state=NORMAL)
        self.reconnectButton.config(state=NORMAL)
        self.barcodeLabel.config(state=NORMAL)
        self.barcodeVarLabel.config(state=NORMAL)
        self.newBarcodeEntry.config(state=NORMAL)
        self.newBarcodeButton.config(state=NORMAL)
        self.assignmentLabel.config(state=NORMAL)
        self.assignmentVarLabel.config(state=NORMAL)

        # assignment frame
        self.typeLabel.config(state=NORMAL)
        self.IDLabel.config(state=NORMAL)
        for i in range(0,8):
            eval("self.sensor%dLabel.config(state=NORMAL)" % i) 
            eval("self.sensor%dTypeLabel.config(state=NORMAL)" % i)        
            eval("self.sensor%dIDLabel.config(state=NORMAL)" % i)
            eval("self.sensor%dnewTypeEntry.config(state=NORMAL)" % i)        
            eval("self.sensor%dnewIDEntry.config(state=NORMAL)" % i)
        self.assignButton.config(state=NORMAL)
        self.resetButton.config(state=NORMAL)
        self.sampleButton.config(state=NORMAL)
        
    def disableUI(self):
        #self.adcLabel.config(state=DISABLED)
        #self.adcVarLabel.config(state=DISABLED)
        self.dcoLabel.config(state=DISABLED)
        self.dcoVarLabel.config(state=DISABLED)
        self.reconnectButton.config(state=DISABLED)
        self.barcodeLabel.config(state=DISABLED)
        self.barcodeVarLabel.config(state=DISABLED)
        self.newBarcodeEntry.config(state=DISABLED)
        self.newBarcodeButton.config(state=DISABLED)
        self.assignmentLabel.config(state=DISABLED)
        self.assignmentVarLabel.config(state=DISABLED)

        # assignment frame
        self.typeLabel.config(state=DISABLED)
        self.IDLabel.config(state=DISABLED)
        for i in range(0,8):
            eval("self.sensor%dLabel.config(state=DISABLED)" % i) 
            eval("self.sensor%dTypeLabel.config(state=DISABLED)" % i)        
            eval("self.sensor%dIDLabel.config(state=DISABLED)" % i)
            eval("self.sensor%dnewTypeEntry.config(state=DISABLED)" % i)        
            eval("self.sensor%dnewIDEntry.config(state=DISABLED)" % i)
        self.assignButton.config(state=DISABLED)
        self.sampleButton.config(state=DISABLED)
        self.resetButton.config(state=DISABLED)

    def changeFocus(self, event):
        event.widget.tk_focusNext().focus()



    def connectSignal(self, connected):
        if connected:
            self.reconnect()
        else:
            self.disableUI()

    def reconnect(self):
        try:
            self.handler.connectToast()
        except:
            self.dcoVar.set("<no device detected>")
            self.assignmentVar.set("<no device detected>")
            self.barcodeVar.set("<no device detected>")
            self.disableUI()
            return
        else:
            self.enableUI()
        
        self.redrawDCO()
        self.redrawBarcode()
        self.redrawAssignments()
    
    def reset(self):
        self.handler.resetToast()
        self.reconnect()

    def sample(self):
        if self.sampling:
            self.sampling = False
            
            self.handler.stopSampling()
            self.enableUI()
            self.sampleButton.config(state=NORMAL, text="Sample")            
        else:
            self.sampling = True
            
            self.sensors = []
            for i in range(0,8):
                if self.assignments[0][i]:
                    self.sensors.append(i)
            
            self.disableUI()
            self.sampleButton.config(state=NORMAL, text="Stop")
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
    

    def updateDCO(self):
        self.handler.updateDCO()
        self.redrawDCO()

    def redrawBarcode(self):
        try:
            barcodeStr = self.handler.getToastBarcode()
        except TagNotFoundError:
            self.barcodeVar.set("<no assignemnts set>")
            self.barcodeVarLabel.config(fg="black")
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
                    tmpType = self.assignments[1][i]
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

            setattr(self, "id", eval("self.sensor%dnewIDVar.get()" % i))
            setattr(self, "type", eval("self.sensor%dnewTypeVar.get()" % i))
            
            if self.id != "":
                try:
                    newID = int(self.id, 16) & 0xFFFF
                except:
                    self.assignmentVar.set("<Invalid input>")
                    self.assignmentVarLabel.config(fg="red")
                    return
                
            if self.type != "":
                try:
                    newType = int(self.type) & 0xFF
                except:
                    self.assignmentVar.set("<Invalid input>")
                    self.assignmentVarLabel.config(fg="red")
                    return

            if (newID and not newType) or (not newID and newType):
                self.assignmentVar.set("<Invalid input>")
                self.assignmentVarLabel.config(fg="red")
                return            
            else:
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
                    eval("self.sensor%dnewTypeVar.set('')" % i)
                self.redrawAssignments()


