



class Hub(object):

    def __init__(self):
        pass
    
    def addNodeFrame(self, frame):
        self.node = frame
    
    def addControlFrame(self, frame):
        self.control = frame
    
    def addDisplayFrame(self, frame):
        self.display = frame
    
    def addStatusFrame(self, frame):
        self.status = frame