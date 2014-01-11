#!/usr/bin/env python

# Copyright (c) 2012 Johns Hopkins University.
# All rights reserved.
# 
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose, without fee, and without written
# agreement is hereby granted, provided that the above copyright
# notice, the (updated) modification history and the author appear in
# all copies of this source code.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS  `AS IS'
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED  TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR  PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR  CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, LOSS OF USE,  DATA,
# OR PROFITS) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR  OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
# THE POSSIBILITY OF SUCH DAMAGE.
# 
#
# @author Jong Hyun Lim <ljh@cs.jhu.edu>
# @author Doug Carlson
#
# @version $Revision$ $Date$
# 

import socket, asyncore, asynchat, struct, array, signal, fcntl, os, time, tos

HOST = '0.0.0.0'
REPROG_PORT = 16462
NSLU_PORT = 16461
STREAM_PORT = 16463
MAX_TOS_LEN = 135

nslus = {}
user_stream = {} # user_stream[mac] = {'to user':[], 'to mote': []}
ui = None
status = {}
mac2id = {}

f = file('map')
for line in f.readlines():
	(mac, node) = line.split()
	mac2id[mac] = node 
f.close()

class NSLUListener(asyncore.dispatcher):
	def __init__(self):
		asyncore.dispatcher.__init__(self)
		self.create_socket(socket.AF_INET, socket.SOCK_STREAM)
		self.set_reuse_addr()
		self.bind((HOST, NSLU_PORT))
		self.listen(1)
	
	def handle_accept(self):
		(conn, addr) = self.accept()
		NSLUHandler(conn, addr)

class NSLUHandler(asyncore.dispatcher):
	cmdMap = {'erase':2, 'reset':3}
	def __init__(self, conn, addr): # addr = (IP, client port)
		self.addr = addr
		self.mac = None
		self.writing = ''
		self.chanListen = None
		print 'New NSLU: ', self.addr
		asyncore.dispatcher.__init__(self, conn)
	
	def handle_read(self):
		packetType = self.recv(1)
		if packetType == '': return 
		packetType = ord(packetType)
		# periodic status message (packetLen = 0) or data from mote 
		if packetType == 0: 
			(mac) = struct.unpack('!8s', self.recv(8))[0]
			if not self.mac and mac in mac2id:
				self.mac = mac 
				print 'New mac:', self.mac, self.addr
				nslus[self.mac] = []
				user_stream[self.mac] = {'to mote':[]}
				self.chanListen = UserChannelListener(self.mac)
			elif mac != self.mac:
				del nslus[mac]
				del user_stream[mac]
				self.mac = mac 
				nslus[self.mac] = []
				user_stream[self.mac] = {'to mote':[]}
			if self.addr[0] not in status: 
				status[self.addr[0]] = {}
			if self.mac not in status[self.addr[0]]:
				status[self.addr[0]][self.mac] = [0,0]
		elif packetType == 1:
			error = struct.unpack('B', self.recv(1))[0] 
			if error == 1: 
				print 'Client:', self.addr, self.mac, 'operation successful'
				status[self.addr[0]][self.mac] = [0,0]
			else: 
				print 'Client:', self.addr, self.mac, 'operation failed'

	def handle_error(self):
		print 'unhandled error'

	def writable(self):
		return self.writing or (self.mac and (self.mac in nslus) and nslus[self.mac])

	def handle_write(self):
		if self.writing: 
			s = self.send(self.writing)
			print 'DEBUG: send', s
			self.writing = self.writing[s:]
		else: 
			if self.mac and (self.mac in nslus) and nslus[self.mac]:
				(cmd, param) = nslus[self.mac][0]
				print 'cmd', cmd
				if cmd in NSLUHandler.cmdMap:
					self.send(chr(NSLUHandler.cmdMap[cmd]))
				elif cmd in ['reprogram', 'reprogram-quick']:
					print 'Sending program %d bytes to %s (%s)'%(len(param), self.addr, self.mac)
					print param 
					self.writing = param 
					self.send(struct.pack('!BI', 1, len(param)))
					s = self.send(param)
					print 'DEBUG: send', s
					self.writing = self.writing[s:]
				del nslus[self.mac][0]

	def handle_close(self):
		print 'Remove NSLU:', self.addr
		self.close()
		if self.mac: 
			del nslus[self.mac]
			del	user_stream[self.mac]
			if len(status[self.addr[0]]) >= 2:
				del status[self.addr[0]][self.mac]
			else: 
				del status[self.addr[0]]
			self.chanListen.close()

class ServerToMoteListener(asyncore.dispatcher):
	def __init__(self):
		asyncore.dispatcher.__init__(self)
		self.create_socket(socket.AF_INET, socket.SOCK_STREAM)
		self.set_reuse_addr()
		self.bind((HOST, STREAM_PORT))
		self.listen(1)

	def handle_accept(self):
		(conn, addr) = self.accept()
		#print 'connection accepted'
		ServerToMoteHandler(conn, addr)

class ServerToMoteHandler(asyncore.dispatcher):
	def __init__(self, conn, addr):
		self.addr = addr
		self.mac = None
		self.id = 0
		self.am = tos.AM(tos.SerialMIB600(conn))
		self.start = 0
		asyncore.dispatcher.__init__(self, conn)

	def handle_connect(self):
		print 'DEBUG: connected to', self.addr, self.port 

	def writable(self):
		return (self.mac and (self.mac in user_stream) and \
			('to mote' in user_stream[self.mac]) and user_stream[self.mac]['to mote'])

	def handle_read(self):
		if self.start == 0:
			(mac) = struct.unpack('!8s', self.recv(8))
			self.mac = mac[0]
			self.id = mac2id[self.mac]
			self.start = 1
		else: 
			(p, op) = self.am.read()
			if p == None and op == None: 
				self.close()
				print 'DEBUG: network closed by ', self.addr
			elif p != None:
				if (self.mac in user_stream) and ('to user' in user_stream[self.mac]):
				#	for i in range(len(op)):
				#		print '%02x'%(op[i]), 
				#	print ''
					user_stream[self.mac]['to user'].append(op)
				# when not a ack packet
				if len(op) > 6: 
					status[self.addr[0]][self.mac][0] += 1 
					if op[9] == 100: # if printf 
						for line in p: 
							if line != '':
								print >>logfile, '%.2f ID:%s'%(time.time(), self.id), line
					else: 
						print >>logfile, '%.2f ID:%s'%(time.time(), self.id), p.data
						
	
	def handle_write(self):
		data = user_stream[self.mac]['to mote'].pop()
		self.send(data)

	def handle_close(self):
		print 'DEBUG: connection closed by', self.addr
		self.close()

class UserChannelListener(asyncore.dispatcher):
	def __init__(self, mac):
		asyncore.dispatcher.__init__(self)
		self.create_socket(socket.AF_INET, socket.SOCK_STREAM)
		self.set_reuse_addr()
		self.mac = mac 
		self.chanHan = None
		if mac in mac2id:
			nodeid = mac2id[mac]
			UPORT = '17'
			# node id be 3-digit
			for i in range(3-len(nodeid)):
				UPORT = UPORT + '0'
			UPORT = UPORT + nodeid
			try:
				self.bind((HOST, int(UPORT)))
				self.listen(1)
			except socket.error, msg: 
				print 'ERROR: binding or listening'
				print 'ERROR: close connection'
				self.close()

	def handle_error(self):
		print 'ERROR: unknown error raised'
		self.close()
		if self.chanHan != None: self.chanHan.close()

	def handle_accept(self):
		(conn, addr) = self.accept()
		if self.chanHan != None: self.chanHan.close()
		self.chanHan = UserChannelHandler(conn, addr, self.mac)

	def handle_close(self):
		self.close()
		if self.chanHan != None: self.chanHan.close()
		if 'to user' in user_stream[self.mac]:
			del user_stream[self.mac]['to user']

class UserChannelHandler(asyncore.dispatcher):
	def __init__(self, conn, addr, mac):	
		self.mac = mac
		self.addr = addr
		user_stream[self.mac]['to user'] = []
		asyncore.dispatcher.__init__(self, conn)

	def writable(self):
		return (self.mac in user_stream) and ('to user' in user_stream[self.mac]) and user_stream[self.mac]['to user']

	def handle_read(self):
		# stream from user to mote 
		if len(user_stream[self.mac]['to mote']) == 0:
			user_stream[self.mac]['to mote'].append(self.recv(MAX_TOS_LEN))

	def handle_write(self):
		for b in user_stream[self.mac]['to user'].pop():
			self.send(struct.pack('B', b))

	def handle_close(self):
		if 'to user' in user_stream[self.mac]: del user_stream[self.mac]['to user']
		print 'DEBUG: user at', self.addr[0],'closed the channel'
		self.close()

class ReprogramListener(asyncore.dispatcher):
	def __init__(self):
		asyncore.dispatcher.__init__(self)
		self.create_socket(socket.AF_INET, socket.SOCK_STREAM)
		self.set_reuse_addr()
		self.bind((HOST, REPROG_PORT))
		self.listen(1)

	def handle_accept(self):
		(conn, addr) = self.accept()
		ReprogramHandler(conn, addr)
	
class ReprogramHandler(asynchat.async_chat):
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
		global ui
		print 'Cmd(%s): %s'%(self.addr, self.buffer)
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
			self.push('%s\n'%nslus.keys())
		elif cmd in ['erase', 'reset', 'reprogram', 'reprogram-quick']:
			c = params[0]
			print 'params', params
			if c not in nslus:
				f = file('map')
				for line in f.readlines():
					(mac, node) = line.split()
					if c == node:
						c = mac
						break
				f.close()
			if c in nslus:
				if cmd == 'reprogram':
					nslus[c].append((cmd, '\n'.join(self.file) + '\n'))
				elif cmd == 'reprogram-quick':
					print 'DEBUG: reprogram-quick', c 
					nslus[c].append((cmd, '\n'.join(self.file) + '\n'))
					self.close_when_done()
				else: 
					nslus[c].append((cmd, None))
			else:
				self.push('ERROR No such client.\n')
			ui = None 
		else:
			self.push('ERROR Available commands are: status, erase, reset, reprogram\n')
		self.buffer = []
		self.close()

	def handle_close(self):
		global ui
		print 'Remove UI:', self.addr
		self.close()
		ui = None

def sigalrm_handler(signum, frame):
	#print 'status:', status 
	#print 'nslus:', nslus
	#print 'mac2id:', mac2id
	#print 'user stream:', user_stream

	f = file('status', 'w')
	fcntl.lockf(f.fileno(), fcntl.LOCK_EX)
	for ip in sorted(status.keys()):
		for (mac, [reads, writes]) in status[ip].items():
			print >>f, ip, mac, mac2id.get(mac,0), reads, writes
	fcntl.lockf(f.fileno(), fcntl.LOCK_UN)
	f.close()

	logfile.flush()
	signal.alarm(5)

signal.signal(signal.SIGALRM, sigalrm_handler)
signal.alarm(5)

logfilename = 'logs/current'
if not os.path.isdir('./logs'):
	os.mkdir('./logs')
if os.path.exists(logfilename) and os.path.getsize(logfilename) != 0:
	os.rename(logfilename, 'logs/%.4f.incomplete'%(time.time()))
logfile = file(logfilename, 'w')

NSLUListener()
ServerToMoteListener()
ReprogramListener()
asyncore.loop()
