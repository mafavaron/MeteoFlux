# rs485 - Module, supporting Meteoflux Core datalogger specific computings
#
# Copyright 2012 by Servizi Territorio srl
#                   All rights reserved
#

import serial
import time
from cpython cimport array
import array

_serial  = None
_speed   = 9600
_timeout = 1

def RS485(port):

	global _serial, _speed
	
	try:
		_serial = serial.Serial(port=port, baudrate=_speed, timeout=_timeout)
	except:
		return False
		
	return True
	
	
def write(line):
	
	global _serial
	
	try:
		_serial.write(line)
	except:
		return False
	return True
	
	
cpdef readline(char* endOfLine = "\r"):
	
	global _serial
	global _timeout
	global _speed
	
	cdef int nchars
	cdef float granularity
	
	# Compute optimal granularity, defined so that (if followed exactly)
	# it would allow receiving 4 characters.
	#
	# One character is 8 bit + 1 start + 1 stop + 1 synch = 11 bit.
	# At 100% channel utilization
	#
	#	granularity = 11 / speed
	#
	# if "speed" is expressed in bit per second (as in this case):
	granularity = 11 / _speed
	
	# Get characters until the terminating character is received, or timeout
	# is reached
	nchars = 0
	line = ""
	startTime = time.time()
	while nchars == 0:
		time.sleep(granularity)
		nchars = _serial.inWaiting()
		line += _serial.read(nchars)
		if len(line) > 0:
			if line[len(line)-1] == endOfLine:
				break
			nchars = 0
		nowTime = time.time()
		if nowTime - startTime > _timeout:
			# Timeout condition encountered
			break
	
	return line


_port	= "/dev/ttyS2"
_speed	= None


cpdef setPort( char* portName ):
	
	global _port
	
	_port = portName
	
	
cpdef getPort():
	
	global _port
	
	return _port
	
	
cpdef setSpeed( int speedVal ):
	
	global _speed
	
	cdef list availableSpeeds = [1200, 2400, 4800, 9600, 19200, 38400]
	_speed = closest( speedVal, availableSpeeds)
	
	
cpdef getSpeed():
	
	global _speed
	
	return _speed
	

cpdef setTimeout( int timeOutValue ):
	
	global _timeout
	
	_timeout = timeOutValue


cpdef int getTimeout():
	
	global _timeout
	
	return _timeout


cpdef int closest(int val, list vector):
	# Find the closest element in integer vector
	
	cdef list dist
	cdef int idxMin, min_val, i

	dist = [abs(vector[i] - val) for i in range(len(vector))]
	idxMin = 0
	min_val = 1000000000
	for i in range(len(dist)):
		if dist[i] < min_val:
			min_val = dist[i]
			idxMin = i
	return vector[idxMin]
	
