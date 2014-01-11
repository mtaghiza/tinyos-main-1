#!/usr/bin/env python

import socket, asyncore, asynchat, struct, array

HOST = '0.0.0.0'
CLIENT_PORT = 16461
UI_PORT = 16462

clients = {}
ui = None

class ClientListener(asyncore.dispatcher):
    def __init__(self):
        asyncore.dispatcher.__init__(self)
        self.create_socket(socket.AF_INET, socket.SOCK_STREAM)
        self.set_reuse_addr()
        self.bind((HOST, CLIENT_PORT))
        self.listen(1)

    def handle_accept(self):
        (conn, addr) = self.accept()
        ClientHandler(conn, addr)

class ClientHandler(asyncore.dispatcher):
    cmdMap = {'erase': 2, 'reset': 3}

    def __init__(self, conn, addr):
        self.addr = addr
        self.mac = None
        self.writing = ''
        print 'New client: ', self.addr
        asyncore.dispatcher.__init__(self, conn)

    def handle_read(self):
        packetType = self.recv(1)
        if packetType == '': return
        packetType = ord(packetType)
        if packetType == 0:
            (mac, reads, writes, packetLen) = struct.unpack('!8siiB', self.recv(8+4+4+1))
            print (mac, reads, writes, packetLen)
            if packetLen > 0: self.recv(packetLen)
            if not self.mac:
                self.mac = mac
                clients[self.mac] = []
            elif mac != self.mac:
                del clients[mac]
                self.mac = mac
                clients[self.mac] = []
        elif packetType == 1:
            error = struct.unpack('B', self.recv(1))[0] 
            print error
            if ui: ui.push('OK %d\n' % error)

    def writable(self):
        return self.writing or (self.mac and clients[self.mac])

    def handle_write(self):
        if self.writing:
            s = self.send(self.writing)
            print 'DEBUG: send', s
            self.writing = self.writing[s:]
        else:
            (cmd, param) = clients[self.mac][0]
            if cmd in ClientHandler.cmdMap:
                self.send(chr(ClientHandler.cmdMap[cmd]))
            elif cmd == 'reprogram':
                print "Sending program %d bytes to %s" % (len(param), self.addr)
                self.writing = param
                self.send(struct.pack('!BI', 1, len(param)))
                s = self.send(param)
                print 'DEBUG: send', s
                self.writing = self.writing[s:]
            del clients[self.mac][0]

    def handle_close(self):
        print 'Remove client:', self.addr
        self.close()
        if self.mac: del clients[self.mac]

class UIListener(asyncore.dispatcher):
    def __init__(self):
        asyncore.dispatcher.__init__(self)
        self.create_socket(socket.AF_INET, socket.SOCK_STREAM)
        self.set_reuse_addr()
        self.bind((HOST, UI_PORT))
        self.listen(1)

    def handle_accept(self):
        (conn, addr) = self.accept()
        UIHandler(conn, addr)

class UIHandler(asynchat.async_chat):
    def __init__(self, conn, addr):
        global ui
        if ui:
            print 'Error: only one UI is supported'
            conn.send('Error: only one UI is supported\n')
            conn.close()
            return
        self.addr = addr
        print 'New UI:', self.addr
        self.set_terminator('\n')
        asynchat.async_chat.__init__(self, conn)
        self.buffer = []
        self.file = []
        ui = self

    def collect_incoming_data(self, data):
        self.buffer.append(data)

    def found_terminator(self):
        print 'Cmd(%s): %s' % (self.addr, self.buffer)
        if self.buffer == []: return
        self.buffer = ''.join(self.buffer)
        if self.buffer[0] == ':':
            self.file.append(self.buffer)
            self.buffer = []
            return
        v = self.buffer.split()
        cmd = v[0]
        params = v[1:]
        if cmd in ['s', 'status']:
            self.push("%s\n" % clients.keys())
        elif cmd in ['erase', 'reset', 'reprogram']:
            c = params[0]
            if c in clients:
                if cmd == 'reprogram':
                    clients[c].append((cmd, '\n'.join(self.file) + '\n'))
                else:
                    clients[c].append((cmd, None))
            else:
                self.push("ERROR No such client.\n")
        else:
            self.push('ERROR Available commands are: status, erase, reset, reprogram\n')
        self.buffer = []

    def handle_close(self):
        global ui
        print 'Remove UI:', self.addr
        self.close()
        ui = None

ClientListener()
UIListener()
asyncore.loop()
