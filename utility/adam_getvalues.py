#!/usr/bin/python

import serial

# Search for AD4xxx modules on a given port
ser = serial.Serial('/dev/ttyS0', 9600, timeout=1)
for i in range(0,1000000):
	cmd = "#01\r"
	ser.write(cmd)
	print cmd
	line = ser.readline()
	if line != "":
		print "Values: %s" % (line)

ser.close()
