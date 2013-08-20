



class Hub(object):

    def __init__(self):
        self.node = None
        self.control = None
        self.display = None
        self.status = None
        
        self.controlKey = False
        self.shiftKey = False
    
    def addNodeFrame(self, frame):
        self.node = frame
    
    def addControlFrame(self, frame):
        self.control = frame
    
    def addDisplayFrame(self, frame):
        self.display = frame
    
    def addStatusFrame(self, frame):
        self.status = frame