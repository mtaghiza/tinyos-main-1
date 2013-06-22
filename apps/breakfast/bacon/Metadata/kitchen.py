from Tkinter import * 
import time
import thread


from ComSelector import ComSelector

bc = 0

def counter():
    while(1):
        global bc
        bc = bc + 1
        time.sleep(1)

def updateTask():
    barcode.set(str(bc))
    barcodeLabel.after(1000, updateTask)

thread.start_new_thread(counter, ())

root = Tk()

comFrame = ComSelector(root)


barcode = StringVar()
barcodeLabel = Label(root, textvariable=barcode)
barcodeLabel.pack()
barcodeLabel.after(1, updateTask)


root.mainloop()

