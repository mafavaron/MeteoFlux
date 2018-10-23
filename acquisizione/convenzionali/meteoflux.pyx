#!/usr/bin/python

# This is the Meteoflux Core Framework, comprising constants and objects to support
# datalogger operation.
#
# This module contains no code in itself. All what it exposes comes from the "imports" 

import time
import os

from local_site  import *
from ad4000      import *
from sa8000      import *
from msglog      import *
from timing      import *
from diagnostics import *
from file_mgmt   import *
from process     import *

# Test driver
if __name__ == "__main__":
	
	print "*** Testing function 'closest' ***"
	print "Expected 10, obtained %f" % closest(10, _availableAveraging)
	print "Expected 1,  obtained %f" % closest(0, _availableAveraging)
	print "Expected 60, obtained %f" % closest(1000, _availableAveraging)
	print "Expected 10,  obtained %f" % closest(10, _availableSampling)
	print "Expected 0.1, obtained %f" % closest(0, _availableSampling)
	print "Expected 60,  obtained %f" % closest(1000, _availableSampling)
	print
	print "*** Testing data set logics"
	print "Creating object"
	ds = DataSet()
	ds.addQuantity("Vel")
	ds.addQuantity("Dir")
	ds.addQuantity("Temp")
	ds.listVariables()
