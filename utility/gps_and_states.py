#!/usr/bin/python

# Task to maintain system RTC aligned with GPS time, coming from a
# Teltonka RUT955 terminal.

import socket
import sys
import time
import os
import logging
import logging.handlers

def getIP():
	
	IP = [(s.connect(('8.8.8.8', 53)), s.getsockname()[0], s.close()) for s in [socket.socket(socket.AF_INET, socket.SOCK_DGRAM)]][0][1]
	return IP


def setRTC(desiredTimeStamp):
	
	timeString = time.strftime("%m%d%H%M%Y.%S", time.gmtime(desiredTimeStamp))
	os.system("date -u %s" % timeString)
	os.system("hwclock -w")
	

def toInt(byteArray):

	i = len(byteArray)
	value = 0
	for b in byteArray:
		value = value*256 + b
		
	return(value)
	

def getGpsData(sock, remoteIP, remotePort):
	
	# Get one data line, check it corresponds to the correct address, and if so pass to the next step
	while True:
		data, adr = sock.recvfrom(4096)
		if adr[0] == remoteIP:
			break
	
	# Convert string to byte array form
	byteArray = bytearray()
	byteArray.extend(map(ord,data))
	if len(byteArray) < 2:
		return None
	
	# Compose message size
	msgSize = toInt(byteArray[0:2])
	packetId = byteArray[2]*256 + byteArray[3]
	packetType = byteArray[4]
	avlId = byteArray[5]
	imeiLen = byteArray[6]*256 + byteArray[7]
	imei = byteArray[8:(8+imeiLen)].decode("utf-8")
	codecId = byteArray[8+imeiLen]
	numData = byteArray[9+imeiLen]
	base    = 10 + imeiLen
	rvTimeStamp = []
	ivPriority  = []
	rvLon       = []
	rvLat       = []
	ivHgt       = []
	ivAng       = []
	ivSat       = []
	ivSpeed     = []
	for i in range(numData):
		timeStamp = toInt(byteArray[base:(8+base)])/1000.0
		priority  = byteArray[8+base]
		lon       = toInt(byteArray[(9+base):(13+base)])/10000000.0
		lat       = toInt(byteArray[(13+base):(17+base)])/10000000.0
		hgt       = toInt(byteArray[(17+base):(19+base)])
		ang       = toInt(byteArray[(19+base):(21+base)])
		sat       = byteArray[21+base]
		speed     = toInt(byteArray[(22+base):(24+base)])
		zeros     = toInt(byteArray[(24+base):(30+base)])
		rvTimeStamp.append(timeStamp)
		ivPriority.append(priority)
		rvLon.append(lon)
		rvLat.append(lat)
		ivHgt.append(hgt)
		ivAng.append(ang)
		ivSat.append(sat)
		ivSpeed.append(speed)
		base += 30
		
	# Send acknowledge packet
	ackPacket = bytearray([0,5,0xCA,0xFE,1,0,0])
	ackPacket[5] = avlId
	ackPacket[6] = numData
	sock.sendto(ackPacket, (remoteIP, remotePort))
	
	outData = (rvTimeStamp, ivPriority, rvLon, rvLat, ivHgt, ivAng, ivSat, ivSpeed)
	
	return(outData)
	
	
def getMostRecentGpsLine(rvTimeStamp, ivPriority, rvLon, rvLat, ivHgt, ivAng, ivSat, ivSpeed):

	# Find the highest time stamp in line set
	rHighestTimeStamp = 0.0
	idx = -1
	for timeStampIdx in range(len(rvTimeStamp)):
		timeStamp = rvTimeStamp[timeStampIdx]
		if timeStamp > rHighestTimeStamp:
			rHighestTimeStamp = timeStamp
			idx = timeStampIdx
	# Post: 'idx' is -1 in case no time stamp was found, or the index of
	#       largest value
	
	if idx < 0:
		return (-9999.9, -9999, -9999.9, -9999.9, -9999, -9999, -9999, -9999)
	
	# Get data
	return (
		rvTimeStamp[idx],
		ivPriority[idx],
		rvLon[idx],
		rvLat[idx],
		ivHgt[idx],
		ivAng[idx],
		ivSat[idx],
		ivSpeed[idx]
	)

def logString(string):
	return "%s - %s" % (time.asctime(), string)
	

def getState():
	
	# Assume active state
	state = 1
	
	# Get the desired state
	try:
		sf = file("/mnt/ramdisk/gps.csv", "r")
		stateNames = sf.readlines()
		sf.close()
		if len(stateNames) > 0:
			stateName = stateNames[0][:-1]	# Get first line up to and excluding 
			if stateName == "active":
				state = 1
			else:
				state = 0
	except:
		state = 1
		
	return state
	
	
if __name__ == "__main__":
	
	logger = logging.getLogger('GPS_Task')
	logger.setLevel(logging.DEBUG)
	handler = logging.handlers.RotatingFileHandler(
			  "/mnt/logs/gps.log", maxBytes=1024*1024, backupCount=5)
	logger.addHandler(handler)
	logger.info(logString("*** Starting execution"))

	oldTimeStamp = 0.0
	isFirst = True
	
	myOwnIP = getIP()
	logger.info(logString("This station's inferred IP: %s" % myOwnIP))

	sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
	logger.info(logString("Socket allocated"))
	try:
		sock.bind((myOwnIP, 17050))
		logger.info(logString("Socket opened on port 17050 (check on Teltonika if same)"))
	except Exception as e:
		logger.error(logString("*** Terminating execution - Error: socket not opened: %s", str(e)))
		sys.exit(1)

	while True:
		
		# Get status from /mnt/ramdisk/gps.dat
		state = getState()
		
		# Act, based on state
		if state == 1:	# Active
		
			# Get most recent data from GPS pool
			(rvTimeStamp, ivPriority, rvLon, rvLat, ivHgt, ivAng, ivSat, ivSpeed) = getGpsData(sock, '192.162.1.1', 17050)
			(rTimeStamp, iPriority, rLon, rLat, iHgt, iAng, iSat, iSpeed) = getMostRecentGpsLine(rvTimeStamp, ivPriority, rvLon, rvLat, ivHgt, ivAng, ivSat, ivSpeed)
			logger.info(logString("Last GPS fix: %f %f %f" % (rLat, rLon, iHgt)))
		
			now = time.time()
			deltaTime = abs(now - rTimeStamp)
			if deltaTime > 10:
				timeAlarm = "***"
				setRTC(rTimeStamp)
				logger.info(logString("RTC updated to GPS"))
			else:
				timeAlarm = ""
			
			# Write GPS status data
			f = open("/mnt/ramdisk/gps_state.txt", "w")
			f.write("Time delta (RTC - GPS): %f %s\n" % (now - rTimeStamp, timeAlarm))
			f.write("Lat, Lon:               %f, %f\n" % (rLat, rLon))
			f.write("Altitude:               %d\n" % iHgt)
			f.write("Angle:                  %d\n" % iAng)
			f.write("Speed:                  %d\n" % iSpeed)
			f.write("Satellites:             %d\n" % iSat)
			f.write("Message priority:       %d\n" % iPriority)
			f.close()
			
			# Write positional data in computer-friendly form
			f = open("/mnt/ramdisk/Position.csv", "w")
			f.write("%f, %f, %d\n" % (rLat, rLon, iHgt))
			f.close()
			
			if isFirst:
				
				isFirst = False
			
			else:
				
				if deltaTime > 60.0:
					
					# No GPS updates ever since: force modem reboot....
					logger.warning(logString("GPS is apparently blocked"))
					
					isFirst = True
					oldTimeStamp = 0.0
					
				else:
					
					oldTimeStamp = rTimeStamp
					
		else: # Waiting: do nothing but waiting a little bit
			
			time.sleep()

	logger.info(logString("*** Terminating execution"))
