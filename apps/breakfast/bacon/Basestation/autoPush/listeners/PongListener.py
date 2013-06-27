#!/usr/bin/env python

class PongListener(object):
    def __init__(self):
        #TODO: should take in a DB
        pass

    def receive(self, src, msg):
        print "Pong from %u id %u rc %u tm %u t32k %u"%(msg.getAddr(),
          msg.get_pingId(), 
          msg.get_rebootCounter(),
          msg.get_tsMilli(),
          msg.get_ts32k())
