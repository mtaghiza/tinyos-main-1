
from CC430bsl import CC430bsl
from CC430bsl.Progress import Progress
import Queue


class Chef(object):


    def __init__(self):
        pass
        

    def connect(self, port, statusVar):
        print port
    
    def disconnect(self, statusVar):
        pass

    def program(self, name, port, callMe):
        print name, port
        self.currentProgress = 0
        input = "-S 115200 -c %s -r -e -I -p %s.ihex" % (port, name)
        
        cc430 = CC430bsl.CC430bsl(input, callMe)
        cc430.start()

    def programProgress(self):
        try:
            while(True):
                self.currentProgress = Progress.wait(False)
        except Queue.Empty:
            pass
        return self.currentProgress

    
