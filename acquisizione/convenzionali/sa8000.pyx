#!/usr/bin/python

# Module supporting B&C Electronics' SA.8000 modules
#
# Copyright 2012 by Servizi Territorio srl
#                   All rights reserved
#

import random
import sys
import time

from meteoflux         import *


from msglog     import *
from local_site import *
from rs485      import *

# Data space, used to hold references to modules

sa8000s = []

# Exceptions

class SA_Error(Exception):
	# Exception, raised on detection of an invalid address
	
	def __init__(self, value):
		self.value = value
	
	def __str__(self):
		return repr(self.value)
		
	
# This is the base class (not intended for direct use)
class SAbase(object):
	# Class, incorporating various functions and data common to all AD4000 series modules.
	# Specific instrument drivers are derived from this one as subclass.

	def __init__(self, address):
		# Constructor of AD module
		
		if address<1 or address>32:
			raise Ad_Error(address)
		
		self.address = address
		self._name   = None
	
	def GetModuleName(self):
		# Auxiliary function, used to read module name
		# in preparation to a confirm the module type assumed by users
		# is the same as the actual one.
		if self._name is not None:
			return self._name
		else:
			return "SA8000"
		
		
	def CheckModule(self):
		# In this "base" class function "CheckModule" always returns
		# True. Real implementation is in derived classes.
		
		return True

		
	def GetModuleAddress(self):
	
		return self.address
		

class SA_sim(SAbase):
	
	def __init__(self, address):
		
		global modules
		
		SAbase.__init__(self, address)
		
		self.SetModuleType("SA_sim")
		sa8000s.append(self)
		
		
	def CheckModule(self):
		
		# Make module "exist"
		return True
		
		
	def ReadData(self):
		# Get analog values (eight, uniformly distributed between -1 and 1, in AD_sim)

		r = [0.0]*6
		for i in range(len(r)):
			r[i] = random.uniform(-1,1)
		return (r, "SA_sim", 0.0)
		
		
	def GetModuleAddress(self):
		
		return self.address


class SA8000(SAbase):
	
	def __init__(self, address):
		
		global modules
		
		SAbase.__init__(self, address)
		sa8000s.append(self)
		
		
	def ReadData(self):
		# Get analog value (unique, in AD4012)
		
		# Perform a read attempt
		self.lastError = 0
		cmd = "%02xA\r" % self.address
		result = write(cmd)
		if not result:
			logMessage("Warning - SA8000/ReadData - Module at address %02x did not accept command" % self.address)
			self.lastError = 1
			return ("SA8000", tuple([None]*6))
		line = readline(endOfLine = "\n")
		if line == "":
			logMessage("Warning - SA8000/ReadData - Module at address %02x did not answer" % self.address)
			self.lastError = 2
			return ("SA8000", tuple([None]*6))
			
		# Check the line received (which is nonempty by preceding test) to be the right length...
		answerLength = len(line)
		if answerLength != 117:
			logMessage("Warning - SA8000/ReadData - Ill-formed answer from module at address %d: %s" % (self.address, answerLength))
			self.lastError = 3
			return ("SA8000", tuple([None]*6))
			
		# ... and the right checksum
		checkSum = 0
		targetChkSum = int(line[113:115], base=16)
		for i in range(113):
			checkSum = checkSum ^ ord(line[i])
		if checkSum != targetChkSum:
			logMessage("Warning - SA8000/ReadData - Corrupted answer from module at address %d: %s" % (self.address, answerLength))
			self.lastError = 4
			return ("SA8000", tuple([None]*6))
		# Post-condition: At normal exit from this text (that is, "here") we are sure "line" to be
		#                 well formed. Then, we may extract data.
		
		# Get module actual model name
		moduleName = line[0:6]
		
		# Get water head (m)
		try:
			head = float(line[32:40])
		except:
			logMessage("Warning - SA8000/ReadData - Invalid head value: '%s'" % line[32:40])
			head = None
		
		# Get water temperature (degrees C)
		try:
			temp = float(line[41:52])
		except:
			logMessage("Warning - SA8000/ReadData - Invalid temperature value: '%s'" % line[41:52])
			temp = None
		
		# Get conductivity (mS)
		try:
			cond = float(line[54:64])
		except:
			logMessage("Warning - SA8000/ReadData - Invalid conductivity value: '%s'" % line[54:64])
			cond = None
		
		# Get pH
		try:
			pH = float(line[66:76])
		except:
			logMessage("Warning - SA8000/ReadData - Invalid pH value: '%s'" % line[66:76])
			pH = None
		
		# Get redox potential (mV)
		try:
			redox = float(line[78:88])
		except:
			logMessage("Warning - SA8000/ReadData - Invalid redox potential value: '%s'" % line[78:88])
			redox = None
		
		# Get oxygen (% of concentration in air)
		try:
			o2 = float(line[90:100])
		except:
			logMessage("Warning - SA8000/ReadData - Invalid oxygen concentration value: '%s'" % line[90:100])
			o2 = None
		
		# Compose output tuple
		values = (head, temp, cond, pH, redox, o2)
		outTuple = (moduleName, values)
		return outTuple
		
if __name__ == "__main__":
	
	# Set time-related data
	setTiming(sampling=2, averaging=1)  # Seconds and minutes respectively
	
	# Set serial port parameters
	setPort("/dev/ttyUSB0")
	setSpeed(2400)
	setTimeout(4)
	
	# Set module(s)
	rtu1 = SA8000(1)	# The module ("rtu no.1", that is, "real-time unit no.1")
	
	# Set diagnostic and operational parameters
	SetBlockOnModuleFailure(True)
	SetIterationsAtModuleCheck(20)
	
	# Data set logics
	data = DataSet("WaterPit1")
	data.addQuantity("H",     Mean)
	data.addQuantity("T",     Mean)
	data.addQuantity("S",     Mean)
	data.addQuantity("pH",    Mean)
	data.addQuantity("Redox", Mean)
	data.addQuantity("Air",   Mean)
	
	# Open serial port
	RS485(
		port  = getPort()
	)
	
	# Get one sample of data
	waterData1 = rtu1.ReadData()
	print "RTU n.1: Last error = %d" % rtu1.lastError
	# (H, T, S, pH, Redox, Air) = waterData1[0]
	
