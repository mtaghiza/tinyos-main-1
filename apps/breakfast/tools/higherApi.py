#!/usr/bin/env python

import sys, time, thread, os

from tinyos.message import *
from tinyos.message.Message import *
from tinyos.message.SerialPacket import *
from tinyos.packet.Serial import Serial
from time import sleep
import mig
from mig import *

import math

class AsyncToSync:
	"""This is a damnable ugly hack.  However, it transforms the async
	message interface of the lower-level API into a proper sync interface.
	Why is the lower-level interface async? I dunno.  It just is.  Magic."""
	receivedMessage=None
	wait=False
	mif=None
	
	def __init__(self,motestring):
		self.sendCount = 0
		self.mif = MoteIF.MoteIF()
		self.tos_source = self.mif.addSource(motestring)
		for messageClass in mig.__all__:
		    if 'Response' in messageClass:
		        self.mif.addListener(self, 
		          getattr(getattr(mig, messageClass), messageClass))
		#TODO: Be hardcore. Actually wait for init
		sleep(1)
		
	def __del__(self):
		"""On object destruction, close all conenctions"""
		if self.mif:
			self.mif.finishAll()
	
	def receive(self, source, message):
		self.receivedMessage=message
		self.wait=False
	
	def send(self, message, dest=0):
		print "Sending",self.sendCount, message
		self.mif.sendMsg(self.tos_source,
		    dest,
		    message.get_amType(), 0,
		    message)
		self.sendCount += 1
		sleep(1)
		ret= self.receivedMessage
		self.receivedMessage=None
		return ret
	
	def initialize(self, destination):
		#turn on bus
		sbp = SetBusPowerCmdMsg.SetBusPowerCmdMsg()
		sbp.set_powerOn(1)
		self.send(sbp, destination)
		time.sleep(0.25)
		#scan
		sb = ScanBusCmdMsg.ScanBusCmdMsg()
		self.send(sb, destination)
		time.sleep(2)

class ManagedCommunication:
	astos = None
	
	E_SUCCESS = 0;
	E_FAIL = 1;
	E_SIZE = 2;
	E_CANCEL = 3;
	E_OFF = 4;
	E_BUSY=5;
	E_INVAL=6;
	E_RETRY=7;   
	E_RESERVE=8;
	E_ALREADY=9;
	E_NOMEM=10;            
	E_NOACK=11;
	
	TOAST_TLV_VERSION=0;
	
	def __init__(self, asynctosync):
		self.astos = asynctosync
		msg = WriteToastVersionCmdMsg.WriteToastVersionCmdMsg()
		msg.set_version(self.TOAST_TLV_VERSION)
		self.sendHelper(msg)
	
	def __del__(self):
		del self.astos
	
	def sendHelper(self, message):
		ret = self.astos.send(message)
		if ret.get_error()==self.E_SUCCESS:
			return ret
		elif ret.get_error()==self.E_RETRY:
			return self.sendHelper(message)
		elif ret.get_error()==self.E_ALREADY:
			#Why is 'its already in the state you asked for' an error?
			ret.set_error(0)
			return ret
		else:
			raise MoteException(ret.get_error(), ret)
	
	def getSensorBusCount(self):
		#power up the bus
		#Send the message asking the sesnor buses to be enumerated
		#then return the count of enumerated busses
		self.sendHelper(SetBusPowerCmdMsg.SetBusPowerCmdMsg("1"))
		return self.sendHelper(ScanBusCmdMsg.ScanBusCmdMsg()).get_numFound()
	
	def getMoteBarcode(self):
		res = self.sendHelper(ReadBaconBarcodeIdCmdMsg.ReadBaconBarcodeIdCmdMsg())
		if res.get_error()==0:
			return res.get_barcodeId()
		else:
			raise NoBarcodeException()
			
	def setMoteBarcode(self, barcode):
		"""Pass barcode as a 16 char string"""
		dmsg = DeleteBaconTlvEntryCmdMsg.DeleteBaconTlvEntryCmdMsg()
		dmsg.set_tag(0x4)
		self.sendHelper(dmsg)
		msg = WriteBaconBarcodeIdCmdMsg.WriteBaconBarcodeIdCmdMsg()
		
		#nehnehnehnehneh I cant convert char to int I'm python nyeh
		code = []
		
		for i in range(0, len(list(barcode))):
			code.insert(i,int(barcode[i]))
		
		msg.set_barcodeId(code)
		self.sendHelper(msg)
		return True
		
	def getMoteVersion(self):
		res = self.sendHelper(ReadBaconVersionCmdMsg.ReadBaconVersionCmdMsg())
		return res.get_version()
	
	def getSensorTypes(self):
		"""Returns a list [0:7] of sensor numeric types"""
		print ReadToastAssignmentsCmdMsg.ReadToastAssignmentsCmdMsg()
		try:
			return self.sendHelper(ReadToastAssignmentsCmdMsg.ReadToastAssignmentsCmdMsg()).get_assignments_sensorType()
		except MoteException as e:
			if e.error==self.E_INVAL:
				return [0] * 8
			else:
				raise e
	
	def getSensorIDs(self):
		"""Returns a list [0:7] of sensor numeric types"""
		try:
			return self.sendHelper(ReadToastAssignmentsCmdMsg.ReadToastAssignmentsCmdMsg()).get_assignments_sensorId()
		except MoteException as e:
			if e.error==self.E_INVAL:
				return [0] * 8
			else:
				raise e
	
	def setSensorType(self, sensor, type):
		"""Sensor is 0 indexed"""
		types = self.getSensorTypes()
		IDs = self.getSensorIDs()
		types[sensor] = type
		msg = WriteToastAssignmentsCmdMsg.WriteToastAssignmentsCmdMsg()
		msg.set_assignments_sensorType(types)
		msg.set_assignments_sensorId(IDs)
		
		return self.sendHelper(msg)
		
	def setSensorID(self, sensor, id):
		"""Sensor is 0 indexed"""
		types = self.getSensorTypes()
		IDs = self.getSensorIDs()
		IDs[sensor] = id
		msg = WriteToastAssignmentsCmdMsg.WriteToastAssignmentsCmdMsg()
		msg.set_assignments_sensorType(types)
		msg.set_assignments_sensorId(IDs)
		
		return self.sendHelper(msg)
		
	def getToastBarcode(self):
		"""Returns teh toast barcode"""
		return self.sendHelper(ReadToastBarcodeIdCmdMsg.ReadToastBarcodeIdCmdMsg())

def findToast():
	"""Find the FIRST connected toast.  Returns an object that can be used to communicate or none if no mote found"""
	possibleToasts=os.listdir("/dev");
	for mfile in possibleToasts:
		print "Testing: " + mfile
		if "ttyUSB" in mfile:
			print "Checking %s" % ('serial@/dev/'+mfile+':115200')
			d=AsyncToSync('serial@/dev/'+mfile+':115200')
			d.initialize(1)
			rm = PingCmdMsg.PingCmdMsg()
			if d.send(rm, 1) is not None:
				return ManagedCommunication(d)
	#Nothing found.
	return None

class NoBarcodeException(BaseException):
	"""Represents no barcode being in the mote"""
	
class MoteException(BaseException):
	"""Represents generic exception from the mote"""
	def __init__(self, error, message):
		self.error = error
		self.message = message
	def __str__(self):
		return u"Error %d occurred: %s" % (self.error, self.message)
				
if __name__=="__main__":
	comms = findToast();
	print "Functioning toast: " , comms
	if comms:
		print "Barcode:" , comms.getMoteBarcode()
		print "Version: ", comms.getMoteVersion()
		print "Connected sensor busses: ", comms.getSensorBusCount()
		comms.setMoteBarcode("98765432")
		print "Barcode (after setting): ", comms.getMoteBarcode()
		comms.setMoteBarcode("12345670")
		
		print comms.getSensorTypes()
		print comms.getSensorIDs()
		print comms.setSensorType(0,1)
		print comms.setSensorID(0,1)
		print comms.getSensorTypes()
		print comms.getSensorIDs()
		
	del comms #force garbage collect of comms and blah blah blah
	#TODO: daemonize other threads!
