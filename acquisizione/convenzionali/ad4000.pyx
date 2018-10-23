# Module supporting Advantech AD4000 modules
#
# Copyright 2012 by Servizi Territorio srl
#                   All rights reserved
#

import random
import sys
import time

from msglog     import *
from local_site import *
from rs485      import *

# Data space, used to hold references to modules

modules = []

# Exceptions

class AD_Error(Exception):
	# Exception, raised on detection of an invalid address
	
	def __init__(self, value):
		self.value = value
	
	def __str__(self):
		return repr(self.value)
		
	
# This is the base class (not intended for direct use)
class AD4000(object):
	# Class, incorporating various functions and data common to all AD4000 series modules.
	# Specific instrument drivers are derived from this one as subclass.

	def __init__(self, address):
		# Constructor of AD module
		
		if address<0 or address>255:
			raise Ad_Error(address)
		
		self.address = address
		
	
	def GetModuleName(self):
		# Auxiliary function, used to read module name
		# in preparation to a confirm the module type assumed by users
		# is the same as the actual one.
		
		cmd = "$%02xM\r" % self.address
		result = write(cmd)
		if not result:
			lastError = 1
			return ""
			
		line = readline()
		if line is None or line == "":
			return ""
		else:
			return line[0:len(line)-1]	# This to strip the terminating "\r"
		
		
	def CheckModule(self):
		# In this "base" class function "CheckModule" always returns
		# True. Real implementation is in derived classes.
		
		return True

		
	def SetModuleType(self, name):
		
		self.name = name
		
		
	def GetModuleType(self):
		
		return self.name
		
		
	def GetModuleAddress(self):
	
		return self.address
		

class AD_sim(AD4000):
	
	def __init__(self, address):
		
		global modules
		
		AD4000.__init__(self, address)
		
		self.SetModuleType("AD_sim")
		modules.append(self)
		
		
	def CheckModule(self):
		
		# Make module "exist"
		return True
		
		
	def ReadAnalog(self):
		# Get analog values (eight, uniformly distributed between -1 and 1, in AD_sim)

		r = [0.0]*8
		for i in range(len(r)):
			r[i] = random.uniform(-1,1)
		return r
		
		
	def CleanCounter(self):
		# Set counter value to zero (to be used on first call, to clean out)
		
		pass
		

	def ReadCounter(self):
		# Return a random value between 0 and 1.
		
		return [random.uniform(0,1)]
		

	def ReadDigital(self):
		# Get 8 digital states in parallel, as the bits of a random byte
		
		byte = random.randint(0,255)
		bvals = [1, 2, 4, 8, 16, 32, 64, 128]
		bits  = [0, 0, 0, 0, 0, 0, 0, 0]
		for i in range(len(bvals)):
			if byte & bvals[i] != 0:
				bits[i] = 1
		return bits
		
	
	def GetModuleAddress(self):
		
		return self.address


class AD4012(AD4000):
	
	def __init__(self, address):
		
		global modules
		
		AD4000.__init__(self, address)
		self.SetModuleType("AD4012")
		modules.append(self)
		
		
	def CheckModule(self):
		
		# Verify module name to exist and be "4012"
		name = AD4000.GetModuleName(self)
		module = name[3:7]
		result = module == "4012"
		if not result:
			logMessage("Warning - AD4012/CheckModule - Module at address %02x did not answer" % self.address)
		return result
		
		
	def ReadAnalog(self):
		# Get analog value (unique, in AD4012)
		
		cmd = "#%02x\r" % self.address
		result = write(cmd)
		if not result:
			logMessage("Warning - AD4012/ReadAnalog - Module at address %02x did not accept command" % self.address)
			self.lastError = 1
			return [None]
			
		line = readline()
		if line is None or line == "":
			logMessage("Warning - AD4012/ReadAnalog - Module at address %02x did not answer" % self.address)
			self.lastError = 2
			return [None]
			
		# Check the module did understand the question
		if line[0] != ">":
			logMessage("Warning - AD4012/ReadAnalog - Module at address %02x gave an invalid answer" % self.address)
			self.lastError = 3
			return [None]
			
		# Extract number from string, convert, and scale to desired units
		try:
			val = float(line[1:len(line)-1])
		except:
			logMessage("Warning - AD4012/ReadAnalog - Module at address %02x gave an invalid answer" % self.address)
			self.lastError = 4
			val = None
		return [val]
		
		
	def CleanCounter(self):
		# Set counter value to zero (to be used on first call, to clean out)
		
		cmd = "@%02xCE\r" % self.address
		result = write(cmd)
		if not result:
			logMessage("Warning - AD4012/CleanCounter - Module at address %02x did not accept command" % self.address)
			self.lastError = 1
			return False
			
		response = readline()
		if response is None or response == "":
			logMessage("Warning - AD4012/CleanCounter - Module at address %02x did not answer" % self.address)
			self.lastError = 2
			return False
			
		# Check the module did understand questions
		if response[0] != '!':
			logMessage("Warning - AD4012/CleanCounter - Module at address %02x gave an invalid answer" % self.address)
			self.lastError = 3
			return False
			
		# Return a "nothing", just for uniformity
		return True
		

	def ReadCounter(self):
		# Get counter value incrementally (that is, reset after successful read)
		
		cmd = "@%02xRE\r" % self.address
		result = write(cmd)
		if not result:
			logMessage("Warning - AD4012/ReadCounter - Module at address %02x did not accept command" % self.address)
			self.lastError = 1
			return [None]
			
		line = readline()
		if line is None or line == "":
			logMessage("Warning - AD4012/ReadCounter - Module at address %02x did not answer" % self.address)
			self.lastError = 2
			return [None]
			
		cmd = "@%02xCE\r" % self.address
		result = write(cmd)
		if not result:
			logMessage("Warning - AD4012/ReadCounter - Module at address %02x did not accept command" % self.address)
			self.lastError = 11
			return [None]
			
		response = readline()
		if response is None or response == "":
			logMessage("Warning - AD4012/ReadCounter - Module at address %02x did not answer" % self.address)
			self.lastError = 12
			return [None]
			
		# Check the module did understand questions
		if line[0] != '!' or response[0] != '!':
			logMessage("Warning - AD4012/ReadCounter - Module at address %02x gave an invalid answer" % self.address)
			self.lastError = 3
			return [None]
			
		# Extract number from string
		try:
			val = float(line[3:len(line)-1])
		except:
			logMessage("Warning - AD4012/ReadCounter - Module at address %02x gave an invalid answer" % self.address)
			self.lastError = 4
			val = [None]
			
		return [val]
		

	def ReadDigital(self):
		# Get digital states
		
		cmd = "@%02xDI\r" % self.address
		result = write(cmd)
		if not result:
			logMessage("Warning - AD4012/ReadDigital - Module at address %02x did not accept command" % self.address)
			self.lastError = 1
			return [None]*8
			
		line = readline()
		if line is None or line == "":
			logMessage("Warning - AD4012/ReadDigital - Module at address %02x did not answer" % self.address)
			self.lastError = 2
			return [None]*8
			
		# Check the module did understand questions
		if line[0] != '!':
			logMessage("Warning - AD4012/ReadDigital - Module at address %02x gave an invalid answer" % self.address)
			self.lastError = 3
			return [None]*8
			
		# Extract number from string (as hex), then retrieve all bits
		try:
			val = int("0x"+line[5:len(line)-1], 16)
		except:
			logMessage("Warning - AD4012/ReadDigital - Module at address %02x gave an invalid answer" % self.address)
			self.lastError = 4
			return [None]*8
		bvals = [1, 2, 4, 8, 16, 32, 64, 128]
		bits  = [0, 0, 0, 0, 0, 0, 0, 0]
		for i in range(len(bvals)):
			if val & bvals[i] != 0:
				bits[i] = 1
		return bits


class AD4015(AD4000):
	
	def __init__(self, address):
		
		global modules
		
		AD4000.__init__(self, address)
		modules.append(self)
		self.SetModuleType("AD4015")
		
		
	def CheckModule(self):
		
		# Verify module name to exist and be "4015"
		name = AD4000.GetModuleName(self)
		module = name[3:7]
		result = module == "4015"
		if not result:
			logMessage("Warning - AD4015/CheckModule - Module at address %02x did not answer" % self.address)
		return result
		
		
	def ForceAllChannelsEnabled(self):
		# Send an all-channel-enable command
		
		cmd = "$%02x5FF\r" % self.address
		result = write(cmd)
		if not result:
			logMessage("Warning - AD4015/ForceAllChannelsEnabled - Module at address %02x did not accept command" % self.address)
			self.lastError = 1
			return False
			
		line = readline()
		if line is None or line == "":
			logMessage("Warning - AD4015/ForceAllChannelsEnabled - Module at address %02x did not answer" % self.address)
			self.lastError = 2
			return False
		
		if line[0] == '!':
			return True
		else:
			logMessage("Warning - AD4015/ForceAllChannelsEnabled - Module at address %02x gave an invalid answer" % self.address)
			return False
		
		
	def ReadAnalog(self):
		# Get analog values (six, in AD4015)
		
		cmd = "#%02x\r" % self.address
		result = write(cmd)
		if not result:
			logMessage("Warning - AD4015/ReadAnalog - Module at address %02x did not accept command" % self.address)
			self.lastError = 1
			return [None]*8
			
		line = readline()
		if line is None or line == "":
			logMessage("Warning - AD4015/ReadAnalog - Module at address %02x did not answer" % self.address)
			self.lastError = 2
			return [None]*8
			
		# Check the module did understand the question
		if line[0] != ">":
			logMessage("Warning - AD4015/ReadAnalog - Module at address %02x gave an invalid answer" % self.address)
			self.lastError = 3
			return [None]*8
			
		# Extract numbers from string, convert, and scale to desired units
		val = [None]*8
		for i in range(6):
			iFrom = 1 + 7*i
			iTo   = iFrom + 7
			try:
				val[i] = float(line[iFrom:iTo])
			except:
				logMessage("Warning - AD4015/ReadAnalog - Module at address %02x gave an invalid answer" % self.address)
				self.lastError = 4
				val = [None]*8
		return val
		
		
	def CleanCounter(self):
		
		return True
		

	def ReadCounter(self):
		
		return [None]
		

	def ReadDigital(self):

		return [None]*8


class AD4017(AD4000):
	
	def __init__(self, address):
		
		global modules
		
		AD4000.__init__(self, address)
		modules.append(self)
		self.SetModuleType("AD4017")
		
		
	def CheckModule(self):
		
		# Verify module name to exist and be "4012"
		name = AD4000.GetModuleName(self)
		module = name[3:7]
		result = module == "4017"
		if not result:
			logMessage("Warning - AD4017/CheckModule - Module at address %02x did not answer" % self.address)
		return result
		
		
	def ForceAllChannelsEnabled(self):
		# Send an all-channel-enable command
		
		cmd = "$%02x5FF\r" % self.address
		result = write(cmd)
		if not result:
			logMessage("Warning - AD4017/ForceAllChannelsEnabled - Module at address %02x did not accept command" % self.address)
			self.lastError = 1
			return False
			
		line = readline()
		if line is None or line == "":
			logMessage("Warning - AD4017/ForceAllChannelsEnabled - Module at address %02x did not answer" % self.address)
			self.lastError = 2
			return False
		
		if line[0] == '!':
			return True
		else:
			logMessage("Warning - AD4017/ForceAllChannelsEnabled - Module at address %02x gave an invalid answer" % self.address)
			return False
		
		
	def ReadAnalog(self):
		# Get analog value (unique, in AD4012)
		
		cmd = "#%02x\r" % self.address
		result = write(cmd)
		if not result:
			logMessage("Warning - AD4017/ReadAnalog - Module at address %02x did not accept command" % self.address)
			self.lastError = 1
			return [None]*8
			
		line = readline()
		if line is None or line == "":
			logMessage("Warning - AD4017/ReadAnalog - Module at address %02x did not answer" % self.address)
			self.lastError = 2
			return [None]*8
			
		# Check the module did understand the question
		if line[0] != ">":
			logMessage("Warning - AD4017/ReadAnalog - Module at address %02x gave an invalid answer" % self.address)
			self.lastError = 3
			return [None]*8
			
		# Extract numbers from string, convert, and scale to desired units
		val = [None]*8
		for i in range(8):
			iFrom = 1 + 7*i
			iTo   = iFrom + 7
			try:
				val[i] = float(line[iFrom:iTo])
			except:
				logMessage("Warning - AD4017/ReadAnalog - Module at address %02x gave an invalid answer" % self.address)
				self.lastError = 4
				val = [None]*8
		return val
		
		
	def CleanCounter(self):
		
		return True
		

	def ReadCounter(self):
		
		return [None]
		

	def ReadDigital(self):

		return [None]*8


class AD4017P(AD4000): # For AD-4017+
	
	def __init__(self, address):
		
		global modules
		
		AD4000.__init__(self, address)
		modules.append(self)
		self.SetModuleType("AD4017+")
		
		
	def CheckModule(self):
		
		# Verify module name to exist and be "4012"
		name = AD4000.GetModuleName(self)
		module = name[3:8]
		result = module == "4017+"
		if not result:
			logMessage("Warning - AD4017+/CheckModule - Module at address %02x did not answer" % self.address)
		return result
		
		
	def ForceAllChannelsEnabled(self):
		# Send an all-channel-enable command
		
		cmd = "$%02x5FF\r" % self.address
		result = write(cmd)
		if not result:
			logMessage("Warning - AD4017+/ForceAllChannelsEnabled - Module at address %02x did not accept command" % self.address)
			self.lastError = 1
			return False
			
		line = readline()
		if line is None or line == "":
			logMessage("Warning - AD4017+/ForceAllChannelsEnabled - Module at address %02x did not answer" % self.address)
			self.lastError = 2
			return False
		
		if line[0] == '!':
			return True
		else:
			logMessage("Warning - AD4017+/ForceAllChannelsEnabled - Module at address %02x gave an invalid answer" % self.address)
			return False
		
		
	def ReadAnalog(self):
		# Get analog value (unique, in AD4012)
		
		cmd = "#%02x\r" % self.address
		result = write(cmd)
		if not result:
			logMessage("Warning - AD4017+/ReadAnalog - Module at address %02x did not accept command" % self.address)
			self.lastError = 1
			return [None]*8
			
		line = readline()
		if line is None or line == "":
			logMessage("Warning - AD4017+/ReadAnalog - Module at address %02x did not answer" % self.address)
			self.lastError = 2
			return [None]*8
			
		# Check the module did understand the question
		if line[0] != ">":
			logMessage("Warning - AD4017+/ReadAnalog - Module at address %02x gave an invalid answer" % self.address)
			self.lastError = 3
			return [None]*8
			
		# Extract numbers from string, convert, and scale to desired units
		val = [None]*8
		for i in range(8):
			iFrom = 1 + 7*i
			iTo   = iFrom + 7
			try:
				val[i] = float(line[iFrom:iTo])
			except:
				logMessage("Warning - AD4017+/ReadAnalog - Module at address %02x gave an invalid answer" % self.address)
				self.lastError = 4
				val = [None]*8
		return val
		
		
	def CleanCounter(self):
		
		return True
		

	def ReadCounter(self):
		
		return [None]
		

	def ReadDigital(self):

		return [None]*8


class AD4019(AD4000):
	
	def __init__(self, address):
		
		global modules
		
		AD4000.__init__(self, address)
		modules.append(self)
		self.SetModuleType("AD4019")
		
		
	def CheckModule(self):
		
		# Verify module name to exist and be "4012"
		name = AD4000.GetModuleName(self)
		module = name[3:7]
		result = module == "4019"
		if not result:
			logMessage("Warning - AD4019/CheckModule - Module at address %02x did not answer" % self.address)
		return result
		
		
	def ForceAllChannelsEnabled(self):
		# Send an all-channel-enable command
		
		cmd = "$%02x5FF\r" % self.address
		result = write(cmd)
		if not result:
			logMessage("Warning - AD4019/ForceAllChannelsEnabled - Module at address %02x did not accept command" % self.address)
			self.lastError = 1
			return False
			
		line = readline()
		if line is None or line == "":
			logMessage("Warning - AD4019/ForceAllChannelsEnabled - Module at address %02x did not answer" % self.address)
			self.lastError = 2
			return False
		
		if line[0] == '!':
			return True
		else:
			logMessage("Warning - AD4019/ForceAllChannelsEnabled - Module at address %02x gave an invalid answer" % self.address)
			return False
		
		
	def ReadAnalog(self):
		# Get analog value (unique, in AD4012)
		
		cmd = "#%02x\r" % self.address
		result = write(cmd)
		if not result:
			logMessage("Warning - AD4019/ReadAnalog - Module at address %02x did not accept command" % self.address)
			self.lastError = 1
			return [None]*8
			
		line = readline()
		if line is None or line == "":
			logMessage("Warning - AD4019/ReadAnalog - Module at address %02x did not answer" % self.address)
			self.lastError = 2
			return [None]*8
			
		# Check the module did understand the question
		if line[0] != ">":
			logMessage("Warning - AD4019/ReadAnalog - Module at address %02x gave an invalid answer" % self.address)
			self.lastError = 3
			return [None]*8
			
		# Extract numbers from string, convert, and scale to desired units
		val = [None]*8
		for i in range(8):
			iFrom = 1 + 7*i
			iTo   = iFrom + 7
			try:
				val[i] = float(line[iFrom:iTo])
			except:
				logMessage("Warning - AD4019/ReadAnalog - Module at address %02x gave an invalid answer" % self.address)
				self.lastError = 4
				val = [None]*8
		return val
		
		
	def CleanCounter(self):
		
		return True
		

	def ReadCounter(self):
		
		return [None]
		

	def ReadDigital(self):

		return [None]*8
