# gps - Module, supporting Meteoflux Core GPS support (for positional daa)
#
# Copyright 2012 by Servizi Territorio srl
#                   All rights reserved
#

from cpython cimport array
import array
import sunlib
import datetime


_lat      = None
_lon      = None
_altitude = None
_fuse     = None


cpdef UpdatePosition():

	global _lat, _lon, _altitude
	
	# Assume success (will falsify on failure)
	success = True
	
	try:
		f = open("/mnt/ramdisk/Position.csv", "r")
		dataLines = f.readlines()
		f.close()
	except:
		success = False
	if len(dataLines) > 0:
		dataLine = dataLines[-1]	# Last, most recent, data line
		parts = dataLine.split(",")
		if len(parts) == 3:
			# Line is OK, parse its contents
			_lat = float(parts[0])
			_lon = float(parts[1])
			_altitude = float(parts[2])
		else:
			# Ill-formed line: let all things as they were originally
			success = False
	else:
		# No position data: let all things as they were originally
		success = False
		
	return success
	
	
cpdef SetPosition(lat, lon, altitude):
	
	global _lat, _lon, _altitude
	
	if lat <= 90 and lat >= -90:
		_lat = lat
	else:
		# No data: assume Cinisello Balsamo coordinates (factory setting)
		_lat = 45.55
	if lon <= 180 and lon >= -180:
		_lon = lon
	else:
		_lon = 9.21
	if altitude >= -430.0:
		_altitude = altitude
	else:
		_altitude = 153.0
	
	
cpdef GetPosition():
	
	return (_lat, _lon, _altitude)
	
	
cpdef SetFuse(double fuse):
	
	_fuse = fuse
	

cpdef double GetFuse():
	
	return _fuse
	
	
cpdef GetSolarData():
	
	curTime = datetime.datetime.now(double zone)
	curTimeStr = curTime.strftime("%Y-%m-%d %H:%M:%S")
	
	return sunlib.sun(_lat, _lon, zone, curTimeStr)
	
