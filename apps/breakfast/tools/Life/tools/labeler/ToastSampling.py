
import threading
import Queue

class ToastSampling(threading.Thread):

    def __init__(self, handler, sensors):
        threading.Thread.__init__(self)

        self.queue = Queue.Queue()
        self._stop = threading.Event()
        self.sensors = sensors
        self.handler = handler

    def stop(self):
        self._stop.set()

    def stopped(self):
        return self._stop.isSet()

    def run(self):
        while(True):
            for s in self.sensors:
                try:
                    time, adc = self.handler.readSensor(s, 2000, 10)
                except:
                    print "ToastSampling: missed sample"
                    pass
                else:
                    self.queue.put((s+1, adc))
            if self.stopped():
                break;
