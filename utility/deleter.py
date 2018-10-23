#!/usr/bin/python

import time
import calendar
import os

def clean(directory, year, month):
	
	dataDir = "%s/%4.4d%2.2d" % (directory, year, month)
	cmd = "rm -f %s/* > cmd.txt" % dataDir
	os.system(cmd)
	cmd = "rmdir %s > cmd.txt" % dataDir
	os.system(cmd)
	print dataDir

if __name__ == "__main__":

	# Get current time, extract current month and deduce which the *previous* month was
	now   = time.gmtime(time.time())
	year  = now.tm_year
	month = now.tm_mon
	month = month - 1
	if month <= 0:
		month = 12
		year  = year - 1

	# Compose directory names
	main = "/mnt/data"
	processed     = main + "/processed"
	diagnostic    = main + "/diagnostic"
	raw           = main + "/raw"
	dl_processed  = main + "/dl_processed"
	dl_diagnostic = main + "/dl_diagnostic"
	dl_raw        = main + "/dl_raw"
	
	# Perform monthly cleanup
	clean(processed, year, month)
	clean(diagnostic, year, month)
	clean(raw, year, month)
	clean(dl_processed, year, month)
	clean(dl_diagnostic, year, month)
	clean(dl_raw, year, month)

