#!/usr/bin/python

import os
import sys
import time
import calendar

TIME_SHIFT = 3600

# Enumerate subdirs from which data to be packed are gathered
# (root dir will be added later)
def enumerateFiles(dateFrom, dateTo, prefix, postfix):

	# Convert dates to UTC date-times
	timeFrom = calendar.timegm(time.strptime(dateFrom, "%Y-%m-%d %H:%M:%S"))
	timeTo   = calendar.timegm(time.strptime(dateTo, "%Y-%m-%d %H:%M:%S"))

	# Iterate over times on hourly basis, and build all possible file names
	fileNames = []
	for tm in range(timeFrom, timeTo+3600, 3600):

		timeStamp = time.strftime("%Y%m%d.%H", time.gmtime(tm))
		subdir    = timeStamp[0:6]
		fName     = os.path.join(prefix, subdir, timeStamp+postfix)
		fileNames.append(fName)

	return fileNames


def packFile(fileNames, outFile):

	isFirst = True

	g = open(outFile, "w")

	for fileName in fileNames:

		try:
			f = open(fileName, "r")
			data = f.readlines()
			for lineNum in range(len(data)):
				if isFirst:
					if lineNum == 0:
						g.write(data[lineNum])
						isFirst = False
				if lineNum > 0:
					g.write(data[lineNum])
				f.close()
		except:
			pass
	
	g.close()


if __name__ == "__main__":
	
	# Get current time in UTC form, and add the shift to simulate local time w/o legal time switch
	now = time.time()+3600
	
	# Go back one hour and its sub-hour fraction: this will be the maximum time considered when extracting data
	lastHour = 3600*(now // 3600) - 3600
	
	# Compute current month beginning
	currentDateTime = time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime(lastHour))
	year            = currentDateTime[0:4]
	month           = currentDateTime[5:7]
	monthStart      = "%4s-%2s-01 00:00:00" % (year, month)
	yearStart       = "%4s-01-01 00:00:00" % year
	

	print currentDateTime
	print yearStart
	print monthStart
	
	# Enumerate files and compact them to unique file (test)
	files = enumerateFiles(monthStart, currentDateTime, "/mnt/data/processed", "p")
	packFile(files, "/mnt/ramdisk/Monthly.csv")
