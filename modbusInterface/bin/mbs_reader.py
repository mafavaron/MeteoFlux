#!/usr/bin/env python
'''
Pymodbus Synchronous Client Examples
--------------------------------------------------------------------------

The following is an example of how to use the synchronous modbus client
implementation from pymodbus.

It should be noted that the client can also be used with
the guard construct that is available in python 2.5 and up::

    with ModbusClient('127.0.0.1') as client:
        result = client.read_coils(1,10)
        print result
'''
#---------------------------------------------------------------------------# 
# import the various server implementations
#---------------------------------------------------------------------------# 
from pymodbus.client.sync import ModbusTcpClient as ModbusClient
#from pymodbus.client.sync import ModbusUdpClient as ModbusClient
#from pymodbus.client.sync import ModbusSerialClient as ModbusClient
from time import sleep
import os
import sys
import yaml
import glob

# Main section

if __name__ == "__main__":

	if len(sys.argv) != 1:
		
		print "mbs_reader.py - Data provider over MODBUS/TCP"
		print
		print "Usage:"
		print
		print "  ./mbs_reader.py"
		print
		print "Copyright 2014 by Servizi Territorio srl"
		print "                  All rights reserved"
		print
		print "Written by: M. Favaron"
		print
		sys.exit(1)
		
	config = "/root/cfg/mbs.cfg"

	# Try getting configuration
	try:
		file = open(config, "r")
		cfg  = yaml.safe_load(file)
		file.close()
	except:
		print "Configuration file, /root/cfg/mbs.cfg, not opened - Aborting"
		sys.exit(1)
	try:
		debug = cfg["Debug"] == "True"
	except:
		debug = False
	try:
		dataFile = cfg["SonicFile"]
	except:
		print "mbs.py:: Error: At least one configuration parameter is missing or misspelled"
		sys.exit(2)
	try:
		convFile = cfg["ConvFile"]
	except:
		print "mbs.py:: Error: At least one configuration parameter is missing or misspelled"
		sys.exit(3)
	try:
		convHeader = cfg["ConvHeader"]
	except:
		print "mbs.py:: Error: At least one configuration parameter is missing or misspelled"
		sys.exit(4)
		
	# Configure the client logging
	#import logging
	#logging.basicConfig()
	#log = logging.getLogger()
	#log.setLevel(logging.DEBUG)

	# Start "sending" client
	sleep(5)	# To make sure the server has started meanwhile
	client = ModbusClient('127.0.0.1', port=502)
	client.connect()

	# Loop to write data
	while(True):

		try:
			
			sleep(1)
			
			# Open sonic file and map its fields for MODBUS transfer
			# -1- Open file the safe way
			try:
				file = open(dataFile, "r")
				data = file.readlines()
				file.close()
			except:
				print "mbs.py:: Error: Sonic file, %s, is missing or inaccessible" % dataFile
				continue
			# -1- First line is the header: split it into component parts and save them to vector (reverse map, from column index to name) and dictionary (direct map from name to column index)
			try:
				fields = data[0][:-1].split(",")
			except:
				print "mbs.py:: Error: Sonic file, %s, contains no lines" % dataFile
				continue
			fieldMap = {}
			i = 0
			for field in fields:
				fieldMap[field] = i
				i = i + 1
				
			# Get last data line
			try:
				values = data[-1][:-1].split(",")
			except:
				print "mbs.py:: Error: Sonic file, %s, contains no discernible data" % dataFile
				continue
			
			# Open conventional data file and map its contents as has been made on sonic file
			# -1- Open file the safe way
			try:
				file = open(convFile, "r")
				datac = file.readlines()
				file.close()
			except:
				print "mbs.py:: Error: Conventional data file, %s, is missing or inaccessible" % convFile
				continue
			# -1- First line is the header: split it into component parts and save them to vector (reverse map, from column index to name) and dictionary (direct map from name to column index)
			try:
				fields = convHeader.split(",")
			except:
				print "mbs.py:: Error: Conventional file header spec in configuration is wrongly formatted"
				continue
			for field in fields:
				fieldMap[field] = i
				i = i + 1
				
			# Append values vector the last data line in conventional file
			try:
				values = values + datac[-1][:-1].split(",")
			except:
				print "mbs.py:: Error: Conventional file header spec in configuration is wrongly formatted"
				continue

			# Check indexes of desired quantities, from configuration
			try:
				q = cfg["Quantities"]
			except:
				print "mbs.py:: Error: No 'Quantities' section in input file"
				continue
			for quantity in q:
				m = q[quantity]
				if m["Type"] == "ISO-DATETIME":
					try:
						idx = fieldMap[quantity]
						dateTime = values[idx]
						year     = int(dateTime[0:4])
						month    = int(dateTime[5:7])
						day      = int(dateTime[8:10])
						hour     = int(dateTime[11:13])
						minute   = int(dateTime[14:16])
						second   = int(dateTime[17:19])
						adrYear   = int(m["AdrYear"])
						adrMonth  = int(m["AdrMonth"])
						adrDay    = int(m["AdrDay"])
						adrHour   = int(m["AdrHour"])
						adrMinute = int(m["AdrMinute"])
						adrSecond = int(m["AdrSecond"])
						rq = client.write_register(adrYear,   year)
						rq = client.write_register(adrMonth,  month)
						rq = client.write_register(adrDay,    day)
						rq = client.write_register(adrHour,   hour)
						rq = client.write_register(adrMinute, minute)
						rq = client.write_register(adrSecond, second)
						if debug:
							print "%4.4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d (%d)" % (year, month, day, hour, minute, second, rq.function_code)
					except:
						if debug:
							print "Unsuccessful attempt to decode date/time"
				elif m["Type"] == "Float":
					try:
						idx = fieldMap[quantity]
						adr = int(m["Adr"])
					except:
						if debug:
							print "Unsuccessful attempt to decode qualtity %s" % quantity
					try:
						rawValue = values[idx]
						reading = float(rawValue)
					except:
						rawValue = -9999.9
						reading = -9999.9
					if reading > -9990.0:
						try:
							val = int(reading*float(m["Multiplier"]) + float(m["Offset"]))
						except:
							val = -9999.9
						if val < 0: # This and the following 3 lines: coerce value to 16 bit, unsigned integer
							val = 0
						elif val > 65535:
							val = 65535
					else:
						val = 0
					rq = client.write_register(adr, val)
					if debug:
						try:
							print "%s -> %d %f %f %f (%d)" % (quantity, val, rawValue, float(m["Multiplier"]), float(m["Offset"]), rq.function_code)
						except:
							pass
					
		except KeyboardInterrupt:
			
			break # Terminate graciously
			
	client.close()
