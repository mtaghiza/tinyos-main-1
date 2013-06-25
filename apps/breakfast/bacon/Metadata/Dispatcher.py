#!/usr/bin/env python

import sys, time, thread

import Queue

import MoteIF
#from tinyos.message import *
#from tinyos.message.Message import *
#from tinyos.message.SerialPacket import *
from tinyos.packet.Serial import Serial
#import tos
import mig
from mig import *

import threading


class PrintfLogger(object):
    def __init__(self):
        self.buf=''
        pass
    
    def receive(self, src, msg):
        mb = msg.get_buffer()
        if 0 in mb:
            mb = mb[:mb.index(0)]
        sys.stdout.write(''.join(chr(v) for v in mb))

class GenericLogger(object):
    
    def __init__(self, q):
        self.queue = q

    def receive(self, src, msg):
        self.queue.put(msg)


class Dispatcher(object):
    mif = None
    queue = None
    tos_source = None
    users = 0
    
    def __init__(self, motestring='serial@/dev/ttyUSB0:115200'):
        if Dispatcher.mif is None:
            #hook up to mote
            Dispatcher.mif = MoteIF.MoteIF()
            Dispatcher.tos_source = Dispatcher.mif.addSource(motestring)

            #format printf's correctly
            Dispatcher.mif.addListener(PrintfLogger(), PrintfMsg.PrintfMsg)

            # use Queue to synchronize communication between send and receive
            # note: queue is thread safe and can block/notify threads
            Dispatcher.queue = Queue.Queue()
            
            # add all message classes found in the mig directory 
            # with the string 'response' in the filename
            for messageClass in mig.__all__:
                if 'Response' in messageClass:
                    Dispatcher.mif.addListener(GenericLogger(Dispatcher.queue), 
                      getattr(getattr(mig, messageClass), messageClass))
                    
                    if __name__ == '__main__':
                        print 'Added: ', getattr(getattr(mig, messageClass), messageClass)
            
            # wait for serial port to complete
            time.sleep(1)
            
        Dispatcher.users = Dispatcher.users + 1

    def stop(self):
        if Dispatcher.users == 1:
            self.mif.finishAll()
            Dispatcher.mif = None
            
        Dispatcher.users = Dispatcher.users - 1 

    def send(self, m, timeout=10):
        Dispatcher.mif.sendMsg(Dispatcher.tos_source,
            0,
            m.get_amType(), 0,
            m)
            
        # note: get will block until queue is not empty or timeout has passed
        try:
            ret = Dispatcher.queue.get(True, timeout)
        except Queue.Empty:
            raise IOError

        # the TinyOS application can be overloaded if called too often
        # insert pause to avoid conflicts
        time.sleep(0.1)

        #print "send()", threading.current_thread().name

        return ret 
    



if __name__ == '__main__':
    packetSource = 'serial@/dev/ttyUSB0:115200'

    if len(sys.argv) < 1:
        print "Usage:", sys.argv[0], "[packetSource=serial@/dev/ttyUSB0:115200] [destination=0x01]" 
        sys.exit()

    if len(sys.argv) > 1:
        packetSource = sys.argv[1]
    if len(sys.argv) > 2:
        destination = int(sys.argv[2], 16)
    
    print packetSource

    n1 = Dispatcher(packetSource)
    n2 = Dispatcher(packetSource)
        
    try:
        time.sleep(2)

        #turn on bus
        sbp = SetBusPowerCmdMsg.SetBusPowerCmdMsg()
        sbp.set_powerOn(1)
        ret = n1.send(sbp)
        
        print ret
        
        #scan
        sb = ScanBusCmdMsg.ScanBusCmdMsg()
        ret = n2.send(sb)
        print ret

        n1.stop()
        n2.stop()
        
        while True:
            time.sleep(2)
    
    #these two exceptions should just make us clean up/quit
    except KeyboardInterrupt:
        pass
    except EOFError:
        pass
    finally:
        print "Cleaning up"
        n.stop()

