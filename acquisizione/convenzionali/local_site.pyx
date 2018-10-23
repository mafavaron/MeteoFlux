#!/usr/bin/python

# This module contains the "definition of site" - used to customize
# Meteoflux Core data logger in a single centralized point.
#
# Imported by "meteoflux"
#
# Copyright 2012 by Servizi Territorio srl
#                   All rights reserved

# Name of directory containing all status information (logs, diagnostic file(s), ...)
_STATE = "/mnt/logs"	# "/root/logs" in Meteoflux Core

# Name of directory containing all data (typically, in Meteoflux Core hardware, a removable card)
_DATA  = "/mnt/ramdisk"	# "/mnt/ramdisk" in Meteoflux Core

# Status logging related information
LOGGING_FILE            = _STATE + "/mfc_dl.log"
LOGGING_FILE_SIZE       = 1024**2						# 1 MByte
LOGGING_NUM_BACKUPS     = 2

# Data sets
RAW_DATA_PATH			= _DATA + ""
PROCESSED_DATA_PATH		= _DATA + ""
DIAGNOSTIC_DATA_PATH	= _DATA + ""
ALARM_LISTS_PATH		= _DATA + ""
	
# Email related
SMTP_SERVER				= "mail.cs.interbusiness.it"
