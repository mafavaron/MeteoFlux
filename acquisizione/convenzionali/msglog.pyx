# Message logging
#
# Copyright 2012 by Servizi Territorio srl
#                   All rights reserved
#

import logging
import logging.handlers

import time

from local_site import *

# Logging

# Set up logging on desired path, in rotating mode, with auto time stamp
_logger = logging.getLogger('MeteofluxCoreDataLogger')
_logger.setLevel(logging.DEBUG)
_handler = logging.handlers.RotatingFileHandler(LOGGING_FILE, maxBytes=LOGGING_FILE_SIZE, backupCount=LOGGING_NUM_BACKUPS)
_logger.addHandler(_handler)

def logMessage(msg):
	
	global _logger
	
	t = time.gmtime(time.time())
	_logger.info("%04d-%02d-%02d %02d:%02d:%02d - %s" % (t.tm_year, t.tm_mon, t.tm_mday, t.tm_hour, t.tm_min, t.tm_sec, msg))
	

def logOverrunEvent():
	
	global _logger
	
	_logger.info("%04d-%02d-%02d %02d:%02d:%02d - Clock overrun detected" % (t.tm_year, t.tm_mon, t.tm_mday, t.tm_hour, t.tm_min, t.tm_sec))
	

