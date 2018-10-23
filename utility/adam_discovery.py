#!/usr/bin/python

import serial

# Search for AD4xxx modules on a given port
ser = serial.Serial('/dev/ttyEX9530', 9600, timeout=1)
for i in range(0,256):
	cmd = "$%2.2xM\r" % i
	ser.write(cmd)
	print cmd
	line = ser.readline()
	if line != "":
		print "Module discovered at address %2.2x: %s" % (i, line)

ser.close()

