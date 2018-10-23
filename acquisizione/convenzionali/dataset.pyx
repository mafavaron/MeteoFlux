#!/usr/bin/env python

# Support routines for multi-hour data sets as seen by
# data acquisition component (both 2D and 3D).

import os
import sys
import datetime
import glob

def readFile(fileName, fieldSep=","):
	
	# Attempt reading data set
	try:
		f = open(fileName, "r")
		data = f.readlines()
		f.close()
		numData = len(data)
	except:
		return {}
		
	# Anything read? A data set should contain a header *and* at least a data line, for a line count of at least two...
	if numData < 2:
		return {}

	# First line is the header: parse it, and compose a dictionary from its contents
	header = data[0][:-1]
	fieldNames = header.split(fieldSep)
	if len(fieldNames) <= 1:
		return {}
	dataSet = {}
	for name in fieldNames:
		dataSet[name] = []
	
	# Populate the data set using the lines following
	for dataLine in data[1:]:
		dataItems = dataLine[:-1].split(fieldSep)
		if len(dataItems) != len(fieldNames):
			return {}
		for fieldIdx in range(len(fieldNames)):
			fieldName  = fieldNames[fieldIdx]
			fieldValue = dataItems[fieldIdx]
			if fieldName == "Date.Time" or fieldName == "Time.Stamp":
				dateValue = datetime.datetime.strptime(fieldValue, "%Y-%m-%d %H:%M:%S")
				dataSet[fieldName].append(dateValue)
			elif fieldName == "Tot.Data" or fieldName == "Valid.Data":
				numValue = int(fieldValue)
				dataSet[fieldName].append(numValue)
			else:
				realValue = float(fieldValue)
				dataSet[fieldName].append(realValue)
				
	# Leave
	return dataSet
	

def concatenateDataSets(ds1, ds2):
	
	# Check data sets contain fields with same names
	names1 = sorted(ds1.keys())
	names2 = sorted(ds2.keys())
	if len(names1) != len(names2):
		return {}
	someDifference = False
	for i in range(len(names1)):
		if names1[i] != names2[i]:
			someDifference = True
			return {}
			
	# Concatenate fields based on their names
	ds = {}
	for k in ds1.keys():
		ds[k] = ds1[k] + ds2[k]
	return ds
	

def getMostRecentData(fileType, prefix, numHours, dataAveragingTime):
	
	# Set pathname elements
	if fileType == "sonic.2d.processed":
		filePrefix  = ""
		filePostfix = "o"
		newData     = "/mnt/ramdisk/CurData2D.csv"
		oldData     = "/mnt/data/processed/"
		tmStampName = "Date.Time"
	elif fileType == "sonic.3d.processed":
		filePrefix  = ""
		filePostfix = "p"
		newData     = "/mnt/ramdisk/CurData.csv"
		oldData     = "/mnt/data/processed/"
		tmStampName = "Date.Time"
	elif fileType == "sonic.3d.diagnostic":
		filePrefix  = ""
		filePostfix = "d"
		newData     = "/mnt/ramdisk/DiaData.csv"
		oldData     = "/mnt/data/diagnostic/"
		tmStampName = "Date.Time"
	elif fileType == "table.processed":
		filePrefix  = prefix + "_"
		filePostfix = "q"
		newData     = "/mnt/ramdisk/" + filePrefix + ".csv"
		oldData     = "/mnt/data/dl_processed/"
		tmStampName = "Time.Stamp"
	else:
		return {}
		
	# Get current data
	newDataSet = readFile(newData)
	
	# Check date and time of current data match the system clock's
	# (if not, an error condition is entered)
	mostRecentTimeStamp = newDataSet[tmStampName][-1]
	now = datetime.datetime.now()
	deltaT = toSeconds(now - mostRecentTimeStamp)
	if deltaT > 2*dataAveragingTime:
		return {}
	# Post-condition: the time differece is compatible with data averaging time
	
	# Define initial search date and time by shifting the last date time found by
	# the desired number of hours
	timeShift = datetime.timedelta(hours=numHours)
	startTime = mostRecentTimeStamp - timeShift
	
	# Generate all hourly file names until now
	oneHour = datetime.timedelta(hours=1)
	dataFiles = []
	currentTime = startTime
	while currentTime < mostRecentTimeStamp:
		fileName = os.path.join(oldData, filePrefix + currentTime.strftime("%Y%m/%Y%m%d.%H") + filePostfix)
		currentTime += oneHour
	
def toSeconds(deltaT):
	return (deltaT.microseconds + 0.0 + (deltaT.seconds + deltaT.days * 24 * 3600) * 1000000.0) / 1000000.0


if __name__ == "__main__":
	
	print getMostRecentData("sonic.2d.processed", "", 24, 600)
