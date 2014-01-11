#!/usr/bin/env python

import socket, asyncore, asynchat, struct, array, time, random

HOST = 'localhost'
PORT = 16461

class Client(asyncore.dispatcher):

    def __init__(self):
        print "Try to connect to %s:%s" % (HOST, PORT)
        asyncore.dispatcher.__init__(self)
        self.create_socket(socket.AF_INET, socket.SOCK_STREAM)
        self.connect((HOST, PORT))
        self.next = time.time()
        self.codeSize = 0
        self.code = ''

    def handle_connect(self):
        pass

    def handle_error(self):
        self.close()
        time.sleep(1)
        self.__init__()

    def handle_close(self):
        self.close()
        time.sleep(1)
        self.__init__()

    def handle_read(self):
        if self.codeSize:
            self.code += self.recv(self.codeSize - len(self.code))
            print "Done", len(self.code), self.codeSize
            if len(self.code) >= self.codeSize:
                self.codeSize = 0
                self.code = ''
                self.send(struct.pack('BB', 1, 0))
            return
        packetType = self.recv(1)
        if packetType == '': return
        packetType = ord(packetType)
        print "Cmd:", packetType
        if packetType in [2, 3]:
            self.send(struct.pack('BB', 1, 0))
        elif packetType == 1:
            self.codeSize = struct.unpack('!I', self.recv(4))[0]
            print "Reprogram", self.codeSize

    def writable(self):
        return time.time() > self.next

    def handle_write(self):
        l = random.randint(20,100)
        data = [random.getrandbits(8) for i in range(l)]
        packedData = struct.pack('!B8siiB', 0, 'M49W90HB', 0, 0, len(data)) + array.array('B', data).tostring()
        print 'Sending...'
        self.send(packedData)
        self.next = time.time() + 1


Client()
asyncore.loop(1)

