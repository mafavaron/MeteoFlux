#!/usr/bin/python

# This program monitors the UPS state, and logs any interesting transition
# to /mnt/logs/ups.log

import smbus
import time
import logging
import logging.handlers

DEVICE_ADDRESS = 0x69
LOGGING_FILE   = "/mnt/logs/ups.log"


def formatString(string):

	return "%s - %s" % (time.asctime(), string)
	

def isPowerOn():

	iPowerBattery = bus.read_byte_data(DEVICE_ADDRESS, 0x00)
	
	return iPowerBattery == 1

	
def isUpsOperational():

	iIncrementingRegister_First = bus.read_byte_data(DEVICE_ADDRESS, 0x22)
	time.sleep(0.1)
	iIncrementingRegister_Second = bus.read_byte_data(DEVICE_ADDRESS, 0x22)
	
	return iIncrementingRegister_First != iIncrementingRegister_Second
	
	
def sayWell(bState):
	
	if bState:
		
		msg = "Power from line."
		
	else:
		
		msg = "Power from battery."
		
	return msg

	
def sayOperational(bState):
	
	if bState:
		
		msg = "Running."
		
	else:
		
		msg = "Waiting."
		
	return msg

	
if __name__ == "__main__":
	
	# Set-up logging, used as the primary method to record interesting events
	# related to UPS operation
	logger = logging.getLogger('UPS_Monitor')
	logger.setLevel(logging.DEBUG)
	handler = logging.handlers.RotatingFileHandler(
			  LOGGING_FILE, maxBytes=1024*1024, backupCount=5)
	logger.addHandler(handler)
	logger.info(formatString("*** Starting execution"))
	
	# Open connection to I2C bus used in SMBUS (simpified) mode
	bus = smbus.SMBus(1)

	# Collect initial state, and log it
	lPowerOn_Old     = isPowerOn()
	#lOperational_Old = isUpsOperational()
	
	logger.info(formatString("Initial power state: %s" % sayWell(lPowerOn_Old)))
	#logger.info(formatString("Initial ups state:   %s" % sayOperational(lOperational_Old)))

	while True:

		# Gather power provenance (1=RPi or power; 2=Battery)
		lPowerOn     = isPowerOn()
		lOperational = isUpsOperational()
		
		# Check if state has changed
		if lPowerOn != lPowerOn_Old:
			lPowerOn_Old = lPowerOn
			logger.info(formatString("Power state changed to: %s" % sayWell(lPowerOn)))
			#logger.info(formatString("UPS state is:           %s" % sayOperational(lPowerOn)))

		#if lOperational != lOperational_Old:
		#	lPowerOn_Old = lPowerOn
		#	logger.info(formatString("UPS state changed to: %s" % sayOperational(lPowerOn)))
		#	logger.info(formatString("Power state is:       %s" % sayWell(lPowerOn)))

		# Wait a bit
		time.sleep(0.5)
