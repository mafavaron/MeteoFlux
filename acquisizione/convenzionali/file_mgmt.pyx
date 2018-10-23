#!/usr/bin/python

# Data file and table management functions and conventions
#
# Copyright 2012 by Servizi Territorio srl
#                   All rights reserved
#

########################
#
# This is likely the most complex part of Meteoflux Core data logger (DL) system. (And beware:
# I wrote it in "my monthly right happy two days", under my usual boost of 15-something points in IQ
# respect to usual - that is, in the remaining part of monthly periods I myself could have difficulties
# unraveling the meanings; see this comment text for some highlights on how this part works,
# hope the best, sorry so sloppy, and thank a lot how our human physiology works in the real world).
#
# Most important in this module is data type "DataSet", implemented as a class, and directing
# all data gathering, storage and processing in a user program.
#
# A "DataSet" is similar somewhat to "tables" in Campbell Scientific's CRBasic - but with some
# important differences:
#
# 1)	Data are always stored in both raw and processed form (in CRBasic, raw storage is attained
#		only through special provisions. (Raw data are typically not collected with Campbell's data loggers,
#		characterized in many cases by a small size internal memory; in Meteoflux Core this is definitely
#		not an issue).
#
# 2)	Intermediate results are not stored to a "circular buffer" but, rather, "accumulated" to
#		a specially-maintained memory area. This, so that processing load is evenly distributed
#		among the various computing phases.
#
# 3)	Syntax, as perceived by end users, is really different from CRBasic's Table(s).
#
# 4)	Some features (in particular long variable names and measurement unit strings) have been
#		intentionally dropped (when I use Campbell dataloggers I typically do not use these
#		facilities, as they tend to clutter output files - a "matter of personal taste by the
#		engineer"; anyhow, I don't pretend this is the "best" way; including long names if
#		necessary "should" be a simple task).
#
# DataSet class instances rely for their operation on aggregation functions, stored in module
# "aggregation_funcs". What's in the class is a (bit complicate) framework.
#
# In more precise terms. Any DataSet instance presents programmers two faces:
#
#	-	Tell the data set which (scalar/complex/vector) quantities s/he would like to store and
#		process, and how.
#
#	-	Specify which physical channel readings enter the quantities.
#
# Of these steps, the first is made on initialization, and the second within data acquisition loop.
# An example of how thing work can be found in this pseudocode snippet:
#
#	def initialize():	# User initialization code - name "initialize" is mandatory
#
#		## Various iniializations, omitted ##
#
#		data = DataSet("MainSet")			# Create the data set instance, and name it "MainSet"
#		data.addQuantity("Wind", WindStat)	# Add quantity "Wind", to be processed using "WindStat" aggregation function
#		data.addQuantity("Temp", Mean)		# Add quantity "Temp" and "Urel", to be just
#		data.addQuantity("Urel", Mean)		# "normally averaged" using aggregator "Mean".
#
#		## Other stuff, unrelevant ##
#
#
#	def loop():		# User data acquisition specification
#
#		## Stuff, instructions, other code ##
#
#		voltages1 = rtu1.ReadAnalog()		# This line actually reads analog values from hardware
#	
#		Vel  = toPhysicalUnits(voltages1[0], multiplier=1.0, offset=7.0)	# Voltages read are converted
#		Dir  = toPhysicalUnits(voltages1[1], multiplier=2.0, offset=6.0)	# to "physical units", so that
#		Temp = toPhysicalUnits(voltages1[2], multiplier=3.0, offset=5.0)	# they gain a meaning from user
#		Urel = toPhysicalUnits(voltages1[3], multiplier=4.0, offset=4.0)	# standpoint. Just for your info.
#
#		data.openDataLine()					# "Hey, look! I'm about to send variable values!"
#		data.addValue("Wind", (Vel, Dir) )	# Sending wind. It is processed by "WindStat", "then" it must be a couple "Vel, Dir"
#		data.addValue("Temp", Temp)			# Sending the two other values.
#		data.addValue("Urel", Urel)
#		data.closeDataLine()				# "OK, no more data to give you, dear DataSet instance 'data': so please,
#											# store raw data and perform any processing.
#
# From users' point of view it is that simple. What happens behind the engine hood, however,
# is quite "rich":
#
#	-	When quantities are added to the data set (member "addQuantity"), two housekeeping structures
#		(list "varNames" and dictionary "varColumn") are update to hold the new quantity, taking
#		provision to ensure no two variables have the same name.
#
#		In the same occasion, a reference to the aggregation function to be used in data processing
#		is also stored. This function is immediately invoked to ask her which intermediate data store will
#		she need during operation (the "accumulator"), how many final output values will be produced
#		as a result of processing, and with which names. This information is used on the fly to
#		initialize an internal instance attribute, "dataSet", holding all accumulators.
#
#		(Routine "addQuantity" is deceptively short: just 9 lines of code. Each one is "heavy",
#		however).
#
#		The order in which quantities are added establishes the precise order in which columns
#		will follow in raw and processed data files. So, saying something like
#
#			addQuantity("Moon", Max)
#			addQuantity("Sun", Min)
#		
#		is not the same thing as
# 
#			addQuantity("Sun", Min)
#			addQuantity("Moon", Max)
#
#		But alas, after quantities have all been added DL "knows" which information will be
#		stored and processed.
#
#	-	With the last "addQuantity" invocation, in practice most of initialization job ends.
#		Now, in the data acquisition loop the same quantities "declared" by addQuantity are
#		populated with measurements and processed.
#
#	-	Member "openDataLine" really does almost nothing: it just reserves the workspace
#		necessary to hold all numbers collected from physical channels. Nothing dramatic, yet needed.
#		(And as far as I've devised, unavoidable).
#
#	-	Member "addValue" acts in a bit more clever: it transfers physical data to their
#		"right" destination. In doing that it acts *by variable name*, not position. This way, users
#		can write
#		
#			addQuantity("Sun",  Min)
#			addQuantity("Moon", Max)
#
#		in initialization part, then write something like
#
#			data.addValue("Moon", MoonValue)
#			data.addValue("Sun",  SunValue)
#
#		in loop part, not respecting original quantity order. I decided so (and *hence the dictionary*!)
#		to avoid users to remember one "irrelevant" detail, hoping to improve use experience.
#
#	-	Where all dirty work occurs is in "closeDataLine" member. The name is somewhat innocuous, but this
#		just to prevent unnecessary "fear" from users. In addition of closing the data line, "closeDataLine"
#		also keeps track of real-time, and acts accordingly.
#
#		More specifically:
#
#		1)	If the last averaging period has just closed, harvest all results, initialize accumulators
#			(indirectly, by invoking the right aggregation functions in accumulator reset mode), and write
#			results to the "processed data" file - after having assigned the "right", initial-interval time stamp.
#
#		2)	Store the data just transferred (the "data line") to both current raw data file and
#			the accumulators (once again, this latter by using the appropriate aggregation functions).
#
#		3)	If an hour has passed, close current data files and open the new ones. Data files are
#			always hourly (this, to prevent cluttering the FAT-based MicroSD file lists with "too much
#			names").
#
#		4)	Perform some more housekeeping.
#
#		Needless to say, "closeDataLine" is long-and-dirty. At least, it "reveals all its complexity
#		at a glance": sincerity?
#
# In general, more than one data sets can be used in the same user program. At least one must
# exist, however, for DL to do something useful.
#
########################

import os
import sys
import time
import math
import shutil

from local_site        import *
from aggregation_funcs import *
from timing            import *

# Directory and file creation/naming

def makeDir(dirName):
	# Create directory without warnings in case it exists already
	
	try:
		os.mkdir(dirName)
	except OSError:
		pass
		

def sameHour(time1, time2):
	
	gmTime1 = time.gmtime(time1)
	gmTime2 = time.gmtime(time2)
	
	return gmTime1.tm_year == gmTime2.tm_year and gmTime1.tm_mon == gmTime2.tm_mon and gmTime1.tm_mday == gmTime2.tm_mday and gmTime1.tm_hour == gmTime2.tm_hour


def sameAveragingBlock(time1, time2, averagingPeriod):

	avgBlock1 = math.floor(time1 / (averagingPeriod * 60))
	avgBlock2 = math.floor(time2 / (averagingPeriod * 60))
	
	return avgBlock1 == avgBlock2


def buildFileName(timeStamp, dataSetName, fileType):
	# Build name of data file, given its type
	
	# Prepare context names, depending in file type
	if fileType == 0:	# Raw
		preDir = RAW_DATA_PATH
		fileLetter = "a"
	elif fileType == 1:	# Processed
		preDir = PROCESSED_DATA_PATH
		fileLetter = "q"
	elif fileType == 2: # Diagnostics
		preDir = DIAGNOSTIC_DATA_PATH
		fileLetter = "g"
	elif fileType == 3: # Failure notifications
		preDir = ALARM_LISTS_PATH
		fileLetter = "f"
	else:
		return ""
		
	# Build file name
	timeStruct = time.gmtime(timeStamp+ 3600*getTimeZone())
	fileName = "%s/%s_%04d%02d%02d.%02d%s" % (preDir, dataSetName, timeStruct.tm_year, timeStruct.tm_mon, timeStruct.tm_mday, timeStruct.tm_hour, fileLetter)
	return fileName
	
	
# Data set class

class DataSet(object):
	
	_MODE_GETACCUM    = 0
	_MODE_STORE       = 1
	_MODE_GETRESULTS  = 2
	_MODE_NUMVARS     = 3
	_MODE_VARSUFFIXES = 4
	
	def __init__(self, name = "", avgTime = 10):
		
		self.numVars = 0
		self.name    = name

		timeStamp = time.time()
		
		# -1- Raw data file
		self.rawDataFileName = buildFileName(timeStamp, name, 0)
		self.rawDataFile = open(self.rawDataFileName, "w")
		
		# -1- Proc data file
		self.procDataFileName = buildFileName(timeStamp, name, 1)
		#self.procDataFile = open(self.procDataFileName, "w")
		
		# -1- Dia data file
		self.diaDataFileName = buildFileName(timeStamp, name, 2)
		self.diaDataFile = open(self.diaDataFileName, "w")
		
		# Append this data set name to yaml config file
		dst = open("/mnt/ramdisk/dataloggerSets.yaml", "a")
		dst.write("  %s :\n" % name)
		dst.close()
		
		# Update time stepping thresholds
		self.oldTimeStamp    = timeStamp
		self.oldAvgTimeStamp = timeStamp
		if avgTime <= 0 or avgTime > 60:
			self.averagingTime = getAveragingPeriod()
		else:
			self.averagingTime = avgTime
		
		self.name = name			# Name (used to form output file names)
		
		self.varColumn = {}			# Column index of variables in set, addressed by name
		self.varNames  = []			# Names of variables in set, addressed by column
		self.varFuncs  = []			# Functions for each variable
		self.varUnits  = []			# Measurement unit for each variable

		self.dataSet   = []			# Actual data set, organized as a per-variable list of "accumulators"
		self.outHeader = []			# Output data header in raw form
		self.numVars   = 0			# Number of variables
		
		self.timeStamp = None		# Line time stamp
		self.values    = None		# A single data line
		
		self.funcs     = None		# List of aggregation functions to apply to each column
	
	
	# Operations made upon initialization, and related to "variables", that is, spaces where
	# readings are placed.
	
	def addQuantity(self, varName, measurementUnit, aggregationFunc):
		# Appends a variable name to the already existing list
		
		if not varName in self.varNames:
			self.varColumn[varName] = self.numVars
			self.varNames.append(varName)
			self.varFuncs.append(aggregationFunc)
			self.varUnits.append(measurementUnit)
			
			outVars = self.varFuncs[self.numVars](self._MODE_GETACCUM)
			self.dataSet.append( outVars[0] )
			outVarNames = [ varName + nm for nm in outVars[1] ]
			self.outHeader.append( outVarNames )
			
			self.numVars += 1

			# Add this quantity name to data logger configuration
			dst = open("/mnt/ramdisk/dataloggerSets.yaml", "a")
			dst.write("    %s : %s\n" % (varName, measurementUnit))
			dst.close()
			
	def listVariables(self):
		# Prints a list of current variables in data set to standard output
		
		for i in self.varColumn:
			print "Column %4d: %s" % (i, self.varColumn[i])
			
	def buildFileHeader(self):
		# Build the string to be used as header in raw data files
		
		header = "Time.Stamp"
		for i in range(len(self.varFuncs)):
			numValues = self.varFuncs[i](self._MODE_NUMVARS)
			varName   = self.varNames[i]
			suffixes  = self.varFuncs[i](self._MODE_VARSUFFIXES)
			for suffix in suffixes:
				header += "," + varName + suffix
				
		return header + "\n"
			
	# Operations made upon data acquisition
		
	def openDataLine(self):
		# Start a new data line
		
		if self.numVars > 0:
			self.timeStamp = getTimeStamp()
			self.values = [None] * self.numVars
			result = True
		else:
			result = False
			
		return result
		
	def addValue(self, varName, varValue):
		# Assign value, given name
		
		if varName in self.varColumn:
			varIdx = self.varColumn[varName]
			self.values[varIdx] = varValue
			result = True
		else:
			result = False
			
		return result
		
	def closeDataLine(self):
		# Assemble the various parts to a whole data line, and save to raw data file
		
		if len(self.values) <= 0:	# No values to process
			return False
		
		# Check time has exceeded end of averaging interval, and in case compute results
		if not sameAveragingBlock(self.timeStamp, self.oldAvgTimeStamp, self.averagingTime):
			
			# Generate just-completed-block time stamp
			averagingDelta = self.averagingTime*60
			currentBlock  = math.floor(self.timeStamp / averagingDelta) * averagingDelta
			procTimeStamp = currentBlock - averagingDelta
			cGmt = time.gmtime(procTimeStamp + 3600*getTimeZone())
			tmStamp = "%04d-%02d-%02d %02d:%02d:%02d" % (cGmt.tm_year, cGmt.tm_mon, cGmt.tm_mday, cGmt.tm_hour, cGmt.tm_min, cGmt.tm_sec)
			
			# Harvest results for the time stamp already completed and reset accumulators
			outLine = []
			for i in range(len(self.varNames)):
				result = self.varFuncs[i](self._MODE_GETRESULTS, accumulator = self.dataSet[i])
				for dataVal in result[0]:
					if dataVal is not None:
						outLine.append( dataVal )
					else:
						outLine.append( -9999.9 )
				self.dataSet[i] = result[1]
			fmtString = tmStamp + ",%f"*len(outLine)
			try:
				stringToWrite = fmtString % tuple(outLine)
			except:
				stringToWrite = fmtString % tuple( [-9999.9]*len(outLine) )
			if os.path.isfile(self.procDataFileName):
				self.procDataFile = open(self.procDataFileName, "a")
			else:
				self.procDataFile = open(self.procDataFileName, "w")
				outHeader = self.buildOutHeader()
				self.procDataFile.write(outHeader)
			self.procDataFile.write( stringToWrite + "\n" )
			self.procDataFile.close()
			
			# Save processed data file to "/mnt/ramdisk"
			tempFile = "/mnt/ramdisk/" + os.path.basename(self.procDataFileName)[0:-13] + ".csv"
			shutil.copyfile(self.procDataFileName, tempFile)
			
			# Update time step detection threshold
			self.oldAvgTimeStamp = self.timeStamp	# ... do nothing on time stamp, as it will automatically set on next loop run
		
		# Update accumulators
		for i in range(len(self.varNames)):
			result = self.varFuncs[i](self._MODE_STORE, value = self.values[i], accumulator = self.dataSet[i])
		
		# Manage file names, on hour change
		if not sameHour(self.timeStamp, self.oldTimeStamp):
			
			# Compute new file names, and create new files
			
			# -1- Raw data file
			self.rawDataFileName = buildFileName(self.timeStamp, self.name, 0)
			try:
				self.rawDataFile.close()
			except:
				pass
			self.rawDataFile = open(self.rawDataFileName, "w")
			header = self.buildFileHeader()
			self.rawDataFile.write(header)
			self.rawDataFile.flush()
			
			# -1- Proc data file
			self.procDataFileName = buildFileName(self.timeStamp, self.name, 1)
			try:
				self.procDataFile.close()
			except:
				pass
			
			# -1- Dia data file
			self.diaDataFileName = buildFileName(self.timeStamp, self.name, 2)
			try:
				self.diaDataFile.close()
			except:
				pass
			self.diaDataFile = open(self.diaDataFileName, "w")
			
			# Update time step detection threshold
			self.oldTimeStamp = self.timeStamp	# ... do nothing on time stamp, as it will automatically set on next loop run
			
		# Prepend time stamp to data string, and log result to raw data file.
		timeVal = time.gmtime(self.timeStamp + 3600*getTimeZone())
		timeString = "%04d-%02d-%02d %02d:%02d:%02d," % (timeVal.tm_year, timeVal.tm_mon, timeVal.tm_mday, timeVal.tm_hour, timeVal.tm_min, timeVal.tm_sec)
		tmpValues = self.values
		for itemIdx in range(len(tmpValues)):
			if type(tmpValues[itemIdx]) == type(None):
				tmpValues[itemIdx] = -9999.9
		values = flatten(tmpValues)
		fmt = "%f" + ",%f"*(len(values)-1)
		valuesString = fmt % values
		self.rawDataFile.write(timeString)
		self.rawDataFile.write(valuesString)
		self.rawDataFile.write("\n")
		self.rawDataFile.flush()
		
	def logStats(self):
		
		pass
		
	def buildOutHeader(self):
		head = flatten(self.outHeader)
		return ("Time.Stamp" + ",%s"*len(head)) % head + "\n"
		
		
		
# Auxiliary functions

def flatten(lst):
	""" Given a list of float, 2dn order tuples, 3rd order tuples and the like, build
	    a single list containing all the same variables one after the other,
	    by their order within each tuple.
	    
	    Example:
	    
			flatten( [1,2,(3,4),5,(6,7,8)] )   yields    [1,2,3,4,5,6,7,8]
			
		This operations is made in preparation to file writes. Simplified, respect to
		"universal flatten" as found in Python literature. """
	
	result = []
	for item in lst:
		try:
			l = len(item)
		except:
			l = 0
		if l == 0:
			result.append(item)
		else:
			for i in range(l):
				result.append(item[i])
	return tuple(result)
	

# Test driver
if __name__ == "__main__":
	
	print "Test starting"
	
	# Set time-related data and wait accordingly (this, to set time stamps the right way)
	setTiming(sampling=2, averaging=1)  # Seconds and minutes respectively
	assignNextAveragingTime()
	waitUntilNext()


	# Build two data sets
	
	data1 = DataSet("MainSet")
	data1.addQuantity("Wind", WindStat)
	data1.addQuantity("Temp", Mean)
	data1.addQuantity("Urel", Mean)
	
	data2 = DataSet("AuxSet")
	data2.addQuantity("Rg",   Mean)
	data2.addQuantity("Rn",   Mean)
	data2.addQuantity("Fg",   Mean)
	data2.addQuantity("Pa",   Mean)
	
	print data1.dataSet
	print data2.dataSet
	
	Vel = 1.
	Dir = 2.
	Temp = 3.
	Urel = 4.
	Rg = 5.
	Rn = 6.
	Fg = 7.
	Pa = 8.
	
	data1.openDataLine()
	data1.oldTimeStamp = data1.timeStamp - 3601.0
	data1.addValue("Wind", (Vel, Dir) )
	data1.addValue("Temp", Temp)
	data1.addValue("Urel", Urel)
	data1.closeDataLine()
	
	data2.openDataLine()
	data2.oldTimeStamp = data2.timeStamp - 3601.0
	data2.addValue("Rg",   Rg)
	data2.addValue("Rn",   Rn)
	data2.addValue("Fg",   Fg)
	data2.addValue("Pa",   Pa)
	data2.closeDataLine()

	print data1.dataSet
	print data2.dataSet
	
	waitUntilNext()
	
	data1.openDataLine()
	data1.addValue("Wind", (Vel, Dir) )
	data1.addValue("Temp", Temp)
	data1.addValue("Urel", Urel)
	data1.closeDataLine()
	
	data2.openDataLine()
	data2.addValue("Rg",   Rg)
	data2.addValue("Rn",   Rn)
	data2.addValue("Fg",   Fg)
	data2.addValue("Pa",   Pa)
	data2.closeDataLine()

	print data1.dataSet
	print data2.dataSet
	
