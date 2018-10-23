#!/usr/bin/python

import serial
import sys
import time

from meteoflux         import *

global DEBUG

DEBUG = False

def initialize():
	
	# Names to be known both in "initialize()" and "loop()"
	global rtu0		# AD4012 at address 1
	global rtu1		# AD4017+ at address 2
	global data		# Output table
	
	# Set time-related data
	setTiming(sampling=1, averaging=10)  # Seconds and minutes respectively
	setTimeZone(1)
	
	# Set serial port parameters
	setPort("/dev/ttyEX9530")
	setSpeed(9600)
	setTimeout(4)
	
	# Set module(s)
	rtu0 = AD4012(1)
	rtu1 = AD4017P(2)	# The module ("rtu no.1", that is, "real-time unit no.1")

	# Set diagnostic and operational parameters
	SetBlockOnModuleFailure(False)
	SetIterationsAtModuleCheck(20)
	
	# Data set logics
	data = DataSet("Meteo")
	data.addQuantity("Temp",     "C", Mean)
	data.addQuantity("Urel",     "Percent", Mean)
	data.addQuantity("RG",       "W/m2", Mean)
	data.addQuantity("RN",       "W/m2", Mean)
	data.addQuantity("RIr",      "W/m2", Mean)
	data.addQuantity("TRIr",     "W/m2", Mean)
	data.addQuantity("Rain_Sum", "mm",   Sum)
	


def loop():
	
	global rtu0
	global rtu1
	global data
	
	# Get data and convert them to physical units
	counter   = rtu0.ReadCounter()
	voltages  = rtu1.ReadAnalog()
	Temp   = toPhysicalUnits(voltages[4], multiplier=100.0, offset=-40.0)
	Urel   = toPhysicalUnits(voltages[5], multiplier=100.0, offset=0.0)
	Rg     = toPhysicalUnits(voltages[1], multiplier=61.3873, offset=0.0)
	Rn     = toPhysicalUnits(voltages[0], multiplier=74.6270, offset=0.0)
	RIr    = toPhysicalUnits(voltages[2], multiplier=116.4144, offset=0.0)
	TRIr   = toPhysicalUnits(voltages[3], multiplier=100.0, offset=0.0)
	Rain   = toPhysicalUnits(counter[0],  multiplier=0.2, offset=0.0)
	
	# Perform range-based validation
	if Temp < -40.0 or Temp > 60.0:
		Temp = None
	if Urel < 0.0 or Urel > 105.0:
		Urel = None
	elif Urel > 100.0:
		Urel = 100.0
	if Rg < 0.0:
		Rg = 0.0
	elif Rg > 1500.0:
		Rg = None
	if Rn < -1500 or Rn > 1500.0:
		Rn = None
	if RIr < -1500.0 or RIr > 1500.0:
		RIr = None
	if TRIr < -40.0 or TRIr > 60.0:
		TRIr = None
	if Rain < 0.0 or Rain > 100.0:
		Rain = None

	# Form data line, append to raw data set, and compute aggregates if required
	data.openDataLine()
	data.addValue("Temp",     Temp)
	data.addValue("Urel",     Urel)
	data.addValue("RG",       Rg)
	data.addValue("RN",       Rn)
	data.addValue("RIr",      RIr)
	data.addValue("TRIr",     TRIr)
	data.addValue("Rain_Sum", Rain)
	data.closeDataLine()

	if DEBUG:
		print("Channel raw values:")
		for i in range(8):
			print("  %1i : %f" % (i, voltages[i])) 
		print("")
		if Temp is not None:
			print("Temp (C)    %f" % Temp)
		if Urel is not None:
			print("Urel (perc) %f" % Urel)
		if Rg is not None:
			print("RG (W/m2)   %f" % Rg)
		if Rn is not None:
			print("RN (W/m2)   %f" % Rn)
		if RIr is not None:
			print("RIr (W/m2)  %f" % RIr)
		if TRIr is not None:
			print("TRIr (W/m2) %f" % TRIr)
		if Rain is not None:
			print("Rain (mm)   %f" % Rain_Sum)
		print("")

	
	if checkTimeToAverage():
		data.logStats()
	
