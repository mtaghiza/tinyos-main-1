import Tkinter
from Tkinter import *

import tools.cx.constants as constants
import tools.cx.CXController as CXController
from tools.dashboard.DatabaseQuery import DatabaseQuery
import tools.cx.DumpCSV as DumpCSV

from threading import Thread
from tools.serial.tools.list_ports import comports

import time

def getDisplayVal(rootStr, channel):
    return "%s (c. %u)"%(rootStr, channel)
   
class ProgressWindow(Toplevel):
    def __init__(self, onClose):
        Toplevel.__init__(self)
        self.protocol("WM_DELETE_WINDOW", onClose)
        self.title = "Download Progress"
        self.focus_set()

        self.messageFrame = Frame(self)
        self.messageText = Text(self.messageFrame, height=10, width=70,
          background='white')

        self.scroll = Scrollbar(self.messageFrame)
        self.messageText.configure(yscrollcommand=self.scroll.set)
        self.scroll.configure(command = self.messageText.yview)

        self.scroll.pack(side="right", fill="y")
        self.messageText.pack(side="left", fill="both", expand=True)
        self.messageFrame.pack(fill="both", expand=True)


    def addMessage(self, message):
        self.messageText.insert(END, message)
        self.messageText.yview(END)

class ControlFrame(Frame):
    DEFAULT_COM_STRING = "<no device detected>"

    DEFAULT_TYPE_STRING = "All Types"
    ROUTERS_STR = "Routers"
    SUBNETWORK_STR = "Manual Subnetwork"
    GLOBAL_STR = "Global"
    DEFAULT_DOWNLOAD_TARGET = (getDisplayVal(SUBNETWORK_STR, 
      constants.CHANNEL_SUBNETWORK_DEFAULT), 
      constants.NS_SUBNETWORK, 
      constants.CHANNEL_SUBNETWORK_DEFAULT)    
    DEFAULT_SITE_STRING = "All Sites"
    SPACING = 10
    DEFAULT_DATA_DIR = "data"

    def __init__(self, parent, hub, dbFile, **args):
        Frame.__init__(self, parent, **args)
        
        self.db = DatabaseQuery(dbFile)
        self.dbFile = dbFile
        self.hub = hub
        self.channels = [0, 31, 63, 95, 159, 191, 223]
        self.connected = False
        self.comDict={}
        self.initUI()
    
    def removeProgressWindow(self):
        self.progressWindow.destroy()
        del self.progressWindow
        self.progressWindow = None

    def progressMessage(self, message):
        if not self.progressWindow:
            self.progressWindow = ProgressWindow(self.removeProgressWindow)
        self.progressWindow.addMessage(message)
        print "PROG %.2f %s"%(time.time(), message,),

    def deviceDetection(self):
        """ Detect serial devices by using the built-in comports command in pyserial.
        """
        # make dictionary with (description, comport)
        newDict = {}
        ports = sorted(comports())
        for port, desc, hwid in ports:
            newDict["%s (%s)"%(port, desc)] = port
        
        # call disconnect function if the current device disappears
        if self.connected and self.comVar.get() not in newDict:
            self.disconnect()
        
        # update menu when not currently connected
        if newDict != self.comDict:
            
            # reset menu
            menu = self.comOption["menu"]
            menu.delete(0, "end")
            
            # keep current selection
            oldIndex = self.comVar.get()
            
            # if devices were found
            if newDict:
                
                # populate menu
                for key in sorted(newDict.keys()):    
                    menu.add_command(label=key, command=Tkinter._setit(self.comVar, key))
                
                # choose first port if no port was previously selected
                if oldIndex not in newDict:
                    self.comVar.set(sorted(newDict.keys())[0])
                self.downloadButton.config(state=NORMAL )
            else:
                menu.add_command(label=self.DEFAULT_COM_STRING, command=Tkinter._setit(self.comVar, self.DEFAULT_COM_STRING))
                self.comVar.set(self.DEFAULT_COM_STRING)
                self.downloadButton.config(state=DISABLED )
            # update
            self.comDict = newDict
        # run detection again after 1000 ms
        self.comOption.after(1000, self.deviceDetection)
    

    def initUI(self):
        self.progressWindow = None
        self.selectionFrame = Frame(self, padx=self.SPACING)
        self.selectionFrame.grid(column=0, row=0)
        #
        #
        #
        self.allFrame = Frame(self.selectionFrame, padx=self.SPACING)
        
        self.allLabel = Label(self.allFrame, text="All: ")
        self.allLabel.grid(column=0, row=0)
        
        self.allTypeVar = StringVar()        
        self.allTypeVar.set(self.DEFAULT_TYPE_STRING)
        self.allTypeOption = OptionMenu(self.allFrame, self.allTypeVar, [self.DEFAULT_TYPE_STRING])
        self.allTypeOption.config(state=DISABLED)
        self.allTypeOption.config(width=len(self.DEFAULT_TYPE_STRING))
        self.allTypeOption.grid(column=1, row=0)
        
        self.allButton = Button(self.allFrame, text="Select", command=self.selectAll)
        self.allButton.grid(column=2, row=0)
        
        self.allFrame.grid(column=0, row=0)


        #
        #
        #
        self.siteFrame = Frame(self.selectionFrame, padx=self.SPACING)
        
        self.siteLabel = Label(self.siteFrame, text="Site: ")
        self.siteLabel.grid(column=0, row=0)
        
        self.siteSiteVar = StringVar()        
        self.siteSiteVar.set(self.DEFAULT_SITE_STRING)
        self.siteSiteOption = OptionMenu(self.siteFrame, self.siteSiteVar, [self.DEFAULT_SITE_STRING])
        self.siteSiteOption.config(state=DISABLED)
        self.siteSiteOption.config(width=len(self.DEFAULT_SITE_STRING))
        self.siteSiteOption.grid(column=1, row=0)

        self.siteTypeVar = StringVar()        
        self.siteTypeVar.set(self.DEFAULT_TYPE_STRING)
        self.siteTypeOption = OptionMenu(self.siteFrame, self.siteTypeVar, [self.DEFAULT_TYPE_STRING])
        self.siteTypeOption.config(state=DISABLED)
        self.siteTypeOption.config(width=len(self.DEFAULT_TYPE_STRING))
        self.siteTypeOption.grid(column=2, row=0)

        self.siteButton = Button(self.siteFrame, text="Select", command=self.selectSite)
        self.siteButton.grid(column=3, row=0)

        self.siteFrame.grid(column=0, row=1)
        
        #
        #
        #
        self.commitFrame = Frame(self.selectionFrame, padx=self.SPACING)
        self.commitButton = Button(self.commitFrame, text="Commit Changes", command=self.commitChanges)
        self.commitButton.grid(column=0, row=0)
        self.commitFrame.grid(column=2, row=0)
        
        #
        self.downloadFrame = Frame(self, padx=self.SPACING)
        self.downloadLabel = Label(self.downloadFrame,
          text="Download From:")
        self.downloadLabel.grid(column=0, row=0)

        self.downloadVar = StringVar()
        self.downloadOption = OptionMenu(self.downloadFrame,
          self.downloadVar, [])
        self.updateDownloadOptions({})
        self.selectDownloadTarget(self.DEFAULT_DOWNLOAD_TARGET)
        self.downloadOption.grid(column=1, row=0)

        self.comVar = StringVar()        
        self.comVar.set(self.DEFAULT_COM_STRING)
        self.comOption = OptionMenu(self.downloadFrame, self.comVar,
          [self.DEFAULT_COM_STRING])
        self.comOption.config(width=25)
        self.comOption.grid(column=0,row=1)

        self.downloadButton = Button(self.downloadFrame, text="Download", command=self.download)
        self.downloadButton.grid(column=1, row=1)
        
        self.repairVar = IntVar()
        self.repairButton = Checkbutton(self.downloadFrame,
          text="Repair", variable=self.repairVar)
        self.repairButton.select()
        self.repairButton.grid(column=2, row=1)


        self.downloadFrame.grid(column=3, row=0)

        self.deviceDetection()

        
   
    def addDownloadOption(self, menu, rootStr, networkSegment, channel):
        displayVal = getDisplayVal(rootStr, channel)
        menu.add_command(label=displayVal,
          command = lambda target=(displayVal, networkSegment, channel):
            self.selectDownloadTarget(target))
        
    def updateDownloadOptions(self, siteChannels):
        menu = self.downloadOption["menu"]
        menu.delete(0, "end")
        self.addDownloadOption(menu, self.ROUTERS_STR, 
          constants.NS_ROUTER, 
          constants.CHANNEL_ROUTER)
        self.addDownloadOption(menu, self.GLOBAL_STR,
          constants.NS_GLOBAL, 
          constants.CHANNEL_GLOBAL)
        for channel in sorted(siteChannels):
            self.addDownloadOption(menu, 
              siteChannels[channel], 
              constants.NS_SUBNETWORK,
              channel)
        for channel in self.channels:
            self.addDownloadOption(menu, self.SUBNETWORK_STR,
              constants.NS_SUBNETWORK, 
              channel)

    def updateSites(self, sites):
        """ Populates drop-down menu with available sites.
            Called from redrawAllNodes in NodeFrame.
        """
        #
        # populate "Site" menu
        #
        menu = self.siteSiteOption["menu"]
        menu.delete(0, "end")
        
        menu.add_command(label=self.DEFAULT_SITE_STRING, command=lambda site=self.DEFAULT_SITE_STRING: self.selectSiteSite(site))
        
        for site in sorted(sites.keys()):
            if site != 0:
                menu.add_command(label=site, command=lambda site=site: self.selectSiteSite(site))
                if self.siteSiteVar.get() == self.DEFAULT_SITE_STRING:
                    self.siteSiteOption.config(state=NORMAL)
    

    def updateTypes(self, types):
        """ Populates drop-down menu with available sensor types.
            Called from redrawAllNodes in NodeFrame.
        """
        
        #
        # populate "All" menu
        #
        menu = self.allTypeOption["menu"]
        menu.delete(0, "end")
        
        menu.add_command(label=self.DEFAULT_TYPE_STRING, command=lambda key=self.DEFAULT_TYPE_STRING: self.selectAllType(key))
        
        for key in sorted(types.keys()):
            if key != 0:
                #menu.add_command(label=key, command=Tkinter._setit(self.allTypeVar, key))
                menu.add_command(label=key, command=lambda key=key: self.selectAllType(key))
                if self.allTypeVar.get() == self.DEFAULT_TYPE_STRING:
                    #self.allTypeVar.set(key)
                    self.allTypeOption.config(state=NORMAL)

        #
        # populate "Site" menu
        #
        menu = self.siteTypeOption["menu"]
        menu.delete(0, "end")
        
        menu.add_command(label=self.DEFAULT_TYPE_STRING, command=lambda key=self.DEFAULT_TYPE_STRING: self.selectSiteType(key))
        
        for key in sorted(types.keys()):
            if key != 0:
                menu.add_command(label=key, command=lambda key=key: self.selectSiteType(key))
                if self.siteTypeVar.get() == self.DEFAULT_TYPE_STRING:
                    self.siteTypeOption.config(state=NORMAL)


    def selectAllType(self, type):
        """ Select all nodes with the specified sensor type attached.
        """        
        self.allTypeVar.set(type)


    def selectAll(self):
        self.hub.display.updateSite("All Sites")
        self.hub.display.updateType(self.allTypeVar.get())
        self.hub.display.redrawAll()
        self.hub.node.redrawAllNodes()


    def selectSiteSite(self, site):
        """ Select all nodes within the specified site.
        """        
        self.siteSiteVar.set(site)

    def selectSiteType(self, type):
        """ Select nodes with the specified sensor type attached in specific site.
        """        
        self.siteTypeVar.set(type)

    def selectSite(self):
        self.hub.display.updateSite(self.siteSiteVar.get())
        self.hub.display.updateType(self.siteTypeVar.get())
        self.hub.display.redrawAll()        
        self.hub.node.redrawAllNodes()

    def selectDownloadTarget(self, t):
        (displayVal, networkSegment, target) = t
        print "SDT:", t
        self.downloadVar.set(displayVal)
        self.networkSegment = networkSegment
        self.downloadChannel = target
    
    def downloadRunner(self):
        #OK, this is kind of ugly: since the global/router channels
        # are fixed, and the channel which is actually used will be
        # read based on the network segment, we don't cause problems
        # by setting this value. Either it will be used (if we're
        # doing a single-patch download) or it will be ignored for
        # globalChannel or routerChannel (depending on the type of
        # download we are doing).
        configMap= {'subNetworkChannel':self.downloadChannel,
          'maxDownloadRounds':1000}
        
        cxCtrl = CXController.CXController(self.dbFile)
        cxCtrl.download('serial@%s:115200'%(self.comDict[self.comVar.get()]),
          self.networkSegment, configMap, 
          refCallBack=self.refCallBack,
          eosCallBack=self.eosCallBack,
          repairCallBack=self.repairCallBack,
          finishedCallBack=self.downloadFinished,
          requestMissing=self.repairVar.get())

    def download(self):
        self.progressMessage( "Download Started: request repairs= %s\n"% ("True" if self.repairVar.get() else "False")) 
        print "Download: %u %u %s"%(self.networkSegment,
          self.downloadChannel, self.comDict[self.comVar.get()])
        self.downloadButton.config(text="DOWNLOADING", bg="green",
          state=DISABLED)
        self.downloadThread = Thread(target=self.downloadRunner,
          name="downloadThread")
        self.downloadThread.daemon = True
        self.downloadThread.start()
        self.downloadProgress()

    def downloadProgress(self):
        """ This function is here to ensure Windows compatibility.
            TKInter on Windows stalls when widgets are updated from other threads.
            This function calls itself every second and checks whether the download
            thread has completed and updates the GUI once done. For some reason the
            thread.join() also stalls the GUI.
        """
        if self.downloadThread.isAlive():
            self.downloadButton.after(1000, self.downloadProgress)
        else:
            self.downloadButton.config(text="Download", bg="gray",
              state=NORMAL)
            self.hub.node.loadSettings()
            self.hub.node.redrawAllNodes()

    def downloadFinished(self, masterId, message):
        """ Callback function. Called by the download thread once done and 
            updates the progress windows with status updates and spawns the
            CSV thread to generate data files from the database.
        """
        self.progressMessage(message)
        (masterId, contacted, found) = self.db.getLastDownloadResults(masterId)
        self.progressMessage("Download finished: %u/%u identified nodes contacted\n"%(contacted, found))

        self.csvThread = Thread(target=self.csvRunner,
          name="csvThread")
        self.csvThread.daemon = True
        self.csvThread.start()


    def csvRunner(self):
        self.progressMessage("Processing data to CSV files\n")
        DumpCSV.dumpCSV(self.dbFile, self.DEFAULT_DATA_DIR)
        self.progressMessage("CSV files ready (under '%s' directory)\n"%
          self.DEFAULT_DATA_DIR )
        for (nodeId, barcodeId, lastSampleTime, lastContact, batteryVoltage) in self.db.contactSummary():
            self.progressMessage("Node %s last sample %s s ago last contact %u s ago battery %s v\n"%(
              barcodeId if barcodeId else hex(nodeId), 
              "%.2f"%(time.time() - lastSampleTime) if lastSampleTime else "NA", 
              time.time() - lastContact,
              "%.2f"%batteryVoltage if batteryVoltage else "NA"))

    def refCallBack(self, node, neighbors, pushCookie, writeCookie,
          missingLength):
        self.progressMessage("Contacted %x (%u neighbors). %d queued, %d in current request\n"%(node, len(neighbors), writeCookie-pushCookie, missingLength))

    def eosCallBack(self, node, status):
        if status == 0:
            self.progressMessage("Node %x NOT reached\n"%(node,))
        if status == 1:
            self.progressMessage(" Node %x transfer completed\n"%(node,))
        if status == 2:
            self.progressMessage(" Node %x transfer continues\n"%(node,))

    def repairCallBack(self, node, length, totalMissing):
        self.progressMessage("Node %x request %u (missing: %u)\n"%(node, length, totalMissing))
    
    def commitChanges(self):
        print "Commit Changes"


    def refresh(self):
        self.hub.node.initUI()
    
    
    
