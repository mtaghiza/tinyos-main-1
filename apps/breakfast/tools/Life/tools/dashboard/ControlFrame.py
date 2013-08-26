import Tkinter
from Tkinter import *


class ControlFrame(Frame):

    DEFAULT_TYPE_STRING = "All Types"
    DEFAULT_SITE_STRING = "All Sites"
    SPACING = 10

    def __init__(self, parent, hub, **args):
        Frame.__init__(self, parent, **args)
        
        self.hub = hub
        
        self.initUI()


    def initUI(self):

        #
        #
        #
        self.allFrame = Frame(self, padx=self.SPACING)
        
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
        self.siteFrame = Frame(self, padx=self.SPACING)
        
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

        self.siteFrame.grid(column=1, row=0)
        
        #
        #
        #
        self.commitFrame = Frame(self, padx=self.SPACING)
        self.commitButton = Button(self.commitFrame, text="Commit Changes", command=self.commitChanges)
        self.commitButton.grid(column=0, row=0)
        self.commitFrame.grid(column=2, row=0)
        
        #self.refreshButton = Button(self, text="Refresh", command=self.refresh)
        #self.refreshButton.grid(column=2, row=0)


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

    
    def commitChanges(self):
        print "Commit Changes"


    def refresh(self):
        self.hub.node.initUI()
    
    
    