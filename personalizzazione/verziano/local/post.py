#!/usr/bin/python

# Personalization program for Brescia Verziano

import sys
import os
import yaml
import time
import calendar
import shutil
import logging

if __name__ == "__main__":

	# Get command line parameters
	if len(sys.argv) != 3:
		
		print "post.py - Personalization process programmed for Meteoflux V3 compatibility box"
		print ""
		print "Usage:"
		print
		print "  ./post.py <CfgFile> <DateTime>"
		print
		print "Copytight 2018 by Servizi Territorio srl"
		print "                  All rights reserved"
		print
		sys.exit(1)
		
	sCfgFile  = sys.argv[1]
	sDateTime = sys.argv[2]
	
	# Start logging (the simple way)
	logging.basicConfig(level=logging.INFO, filename="/mnt/ramdisk/hourly.log", filemode="w")
	logger = logging.getLogger("hourly")
	logger.info("Starting execution")
	logger.info("   Cfg file: %s", sCfgFile)
	logger.info("   Datetime: %s", sDateTime)

	# Retrieve configuration
	cfgFile = open(sCfgFile, "r")
	cfg     = yaml.safe_load(cfgFile)
	cfgFile.close()
	dataPrefix = cfg["DataPrefix"]
	logger.info("Configuration retrieved")
	
	# Locate the desired files, and copy them back to RAM disk, to ease access by R-written averaging script
	tHourToProcess = time.strptime(sDateTime, "%Y-%m-%d %H:%M:%S")
	iDay           = tHourToProcess.tm_mday
	iMonth         = tHourToProcess.tm_mon
	iYear          = tHourToProcess.tm_year
	iHour          = tHourToProcess.tm_hour
	sSonicFile = "/mnt/data/processed/%4.4d%2.2d/%4.4d%2.2d%2.2d.%2.2dp" % (iYear, iMonth, iYear, iMonth, iDay, iHour)
	sDLFile    = "/mnt/data/dl_processed/%4.4d%2.2d/%s_%4.4d%2.2d%2.2d.%2.2dq" % (iYear, iMonth, dataPrefix, iYear, iMonth, iDay, iHour)
	logger.info("Input data file names generated:")
	logger.info("  Sonic >> %s", sSonicFile)
	logger.info("  DL    >> %s", sDLFile)
	
	# Copy the desired files to RAM disk under fixed names
	try:
		if os.path.isfile("/mnt/ramdisk/Data_SN.csv"):
			os.remove("/mnt/ramdisk/Data_SN.csv")
	except Exception as e:
		logger.info("Exception trying to delete standard sonic data file - " + str(e))
	else:
		logger.info("Sonic data standard file cleaned")
	try:
		if os.path.isfile("/mnt/ramdisk/Data_DL.csv"):
			os.remove("/mnt/ramdisk/Data_DL.csv")
	except Exception as e:
		logger.error("Exception trying to delete standard datalogger file - " + str(e))
	else:
		logger.info("Data logger standard file cleaned")
	isSonic = False
	try:
		shutil.copyfile(sSonicFile, "/mnt/ramdisk/Data_SN.csv")
		isSonic = True
	except Exception as e:
		logger.error("Sonic data file not transferred - " + str(e))
	else:
		logger.info("Sonic data file transferred successfully")
	isConv = False
	try:
		shutil.copyfile(sDLFile,    "/mnt/ramdisk/Data_DL.csv")
		isConv = True
	except Exception as e:
		logger.error("Data logger file not transferred - " + str(e))
	else:
		logger.info("Data logger file transferred successfully")

	# Add a header line if not present
	if isConv:
		inFile = open("/mnt/ramdisk/Data_DL.csv", "r")
		lines = inFile.readlines()
		inFile.close()
		if len(lines) > 0:
			header = lines[0]
			if header[0:1] == "2": # Header is missing: add a fictive one (actual field names will be forced by "averager.R"
				outFile = open("/mnt/ramdisk/Data_DL.csv", "w")
				outFile.write("f1,f2,f3,f4,f5,f6,f7,f8\n")
				for line in lines:
					outFile.write(line)
				outFile.close()
			logger.info("Header line added to datalogger file")
	
	# Run the R script performing actual averages
	try:
		if os.path.isfile("/mnt/ramdisk/hourly_averages.dat"):
			os.remove("/mnt/ramdisk/hourly_averages.dat")
	except Exception as e:
		logger.error("Hourly averages file not removed - "+str(e))
	try:
		if os.path.isfile("/mnt/ramdisk/hourlyData.aqg"):
			os.remove("/mnt/ramdisk/hourlyData.aqg")
	except Exception as e:
		logger.error("AQG prototype file not removed - "+str(e))
	if isSonic and isConv:
		try:
			os.system("/usr/bin/Rscript /home/standard/local/averager.R")
			logger.info("Program 'averager.R' execution completed")
		except Exception as e:
			logger.error("Program 'averager.R' not executed")
	elif isSonic:
		try:
			os.system("/usr/bin/Rscript /home/standard/local/averager_onlysonic.R")
			logger.info("Program 'averager_onlysonic.R' execution completed")
		except Exception as e:
			logger.error("Program 'averager_onlysonic.R' not executed")
	elif isConv:
		try:
			os.system("/usr/bin/Rscript /home/standard/local/averager_onlyconv.R")
			logger.info("Program 'averager_onlyconv.R' execution completed")
		except Exception as e:
			logger.error("Program 'averager_onlyconv.R' not executed")
	
	# Get R output, change its form and name and move to final directory
	# -1- Check data file exists (it should, past "averager.R" execution),
	#     and if in case read it to an input string set
	if not os.path.isfile("/mnt/ramdisk/hourlyData.aqg"):
		logger.error("Program 'averager.R' did produce no output")
		sys.exit(2)
	rslFile = open("/mnt/ramdisk/hourlyData.aqg", "r")
	rslData = rslFile.readlines()
	rslFile.close()
	# -1- Form output file name and directory
	outFile = "/mnt/data/aqg/00000AQG%4.4d%2.2d%2.2d.%2.2d" % (iYear, iMonth, iDay, iHour)
	outDir  = "/mnt/data/aqg"
	# -1- String normalization
	normData = []
	for data in rslData:
		# -2- Strip '"' characters
		data = data.replace('"', "")
		# -2- Replace all commas to blanks
		data = data.replace(","," ")
		# -2- Change forward to back slashes
		#data = data.replace("/","\\")
		# -2- Replace "us" with "u*"
		data = data.replace("us","u*")
		# -2- Prepend a blank to anything else
		#data = " " + data
		# -2- Change UNIX to Windows line terminators
		data = data.replace("\n","\r\n")
		# -2- Append normalized line to new data file
		normData.append(data)
	logger.info("Output from 'averager.R' program gathered successfully")
	# -1- Create out dir, if not present
	if not os.path.exists(outDir):
		os.makedirs(outDir)
	# -1- Write to disk in binary form (to prevent UNIX to mess Win line terminators)
	f = open(outFile, "wb")
	for data in normData:
		f.write(data)
	logger.info("Output from 'averager.R' program transferred to %s. Execution completed successfully.", outFile)

