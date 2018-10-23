#!/usr/bin/python

import serial

# $018C5 reads configuration on channel 5

# Search for AD4xxx modules on a given port
ser = serial.Serial('/dev/ttyS0', 9600, timeout=1)

# Change channel 5 cfg
cmd = "$017C4R09\r"
ser.write(cmd)
print cmd
line = ser.readline()
if line != "":
	print "Module cfg changed: %s" % (line)

# Channel 5: get cfg
cmd = "$019C4\r"
ser.write(cmd)
print cmd
line = ser.readline()
if line != "":
	print "Module cfg chan 5: %s" % (line)
ser.close()

