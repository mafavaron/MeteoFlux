# Data aggregation on output
#
# Copyright 2012 by Servizi Territorio srl
#                   All rights reserved
#

######################
#
# Conventions used
# ================
#
# This part of the Meteoflux Core data logger (aka "DL") contains the aggregate functions,
# used to process the data gathered.
#
# All aggregation functions share a unique, mandatory interface:
#	
#	aggregateFunction(mode, value=None, accumulator=None)
#	
# The only mandatory parameter is "mode", an integer number with the following values:
#
#	0 :		Give framework information about which intermediate and final data are to be
#			treated by this function.
#
#			No other input is considered in this mode. The function yields an ordered couple,
#
#				( Accumulators, Names )
#
#			where "Accumulators" is a list of the form
#
#				[ 0, 0.0, 0.0, ..., 0.0 ]
#
#			(that is, an integer 0 followed by 1 or more floating point zeros), used by
#			the framework to hold intermediate values on which the function is activated
#			as needed.
#
#			"Names", on the other side, is a list of string, each one containing the suffix
#			which will be appended to the quantity name to fully qualify it. FOr example,
#			a quantity named "Rg" can be qualified by a suffix like ".Mean", or ".Max", or
#			whatever else depending on which function is actually invoked.
#
#	1 :		Update accumulators.
#
#			In this mode both "value" and "accumulator" parameters are used.
#
#			The actual mechanics depends on which aggregation function is invoked, but the
#			processing always follows a very simple path: value(s) is (are) gathered from
#			"value", and summed up into the actual contents of "accumulator".
#
#			"value" is spelled in singular number, not plural, because it is always a single
#			entity. Most often it is a floating point number representing some measured scalar.
#			But in some very special cases it may contain a tuple holding floats. FOr example,
#			in standard wind vector processing the contents of "value" is a tuple having form
#
#				(Wind speed, Wind direction)
#
#			(that is, it represent a complex number in module-argument form, with argument angle
#			following the "geological" convention for azimuth, instead the geometric one).
#
#	2 :		Harvest results.
#
#			In this mode, "value" parameter is ignored, and "accumulator" is used to
#			process data summed up until now.
#
#			The actual processing depends on which aggregation function is used.
#
#			Result consists in a list containing one or more flloating point numbers; this
#			list's length must be identical to the length of "Names" list, as returned
#			in mode 0 call.
#
#	3 :		Get number of floating point numbers in "value" input.
#
#			In this call both "value" and "accumulator" parameters are ignored. The result is
#			an integer number. If its value is 1, then "value" in mode 1 is expected to contain
#			a floating point value. If it is 0, then "value" is not used (may be, in very
#			specific cases). If larger than 1, then a tuple with this number of floats is
#			expected.
#
#	4 :		Get suffix to be applied to input variables.
#
#			In this mode, "value" and "accumulator" are both ignored.
#
#			Output is a list of (possibly empty) string(s), holding the suffixes desired. Length
#			of this list coincides with value returned in mode 3.
#
# These conventions should be followed strictly, when adding new aggregate functions.
#
######################

import math

def Nothing(mode, value=None, accumulator=None):
	
	if mode==1:
		return True
		
	elif mode==2:
		return ([], [])
		
	elif mode == 0:
		return ([],())
		
	elif mode == 3:
		return 0
		
	elif mode == 4:
		return [""]
		
	
def Mean(mode, value=None, accumulator=None):
	
	if mode == 1:
		# Update accumulator (most common call, invoked on each sampling act)
		if accumulator is not None:
			if value is not None and type(value) is list:
				if value[0] is not None:
					accumulator[0] += 1
					accumulator[1] += value[0]
			elif value is not None and type(value) is float:
				accumulator[0] += 1
				accumulator[1] += value
			result = True
		else:
			result = False
			
	elif mode == 2:
		# Compute result and reset accumulator (invoked on each averaging)
		if accumulator[0] is not None and accumulator[0] > 0:
			if accumulator[1] is not None:
				mean = accumulator[1] / accumulator[0]
			else:
				mean = None
		else:
			mean = None
		return ([mean], [0, 0.0] )
		
	elif mode == 0:
		# "How would you like an accumulator be made for you? And, which suffixes in result?" (invoked once, upon configuration)
		accum = [
			0,		# Number of valid values added
		    0.0		# Running sum of valid values
		]
		names = (
			".Mean",	# Comma is necessary in Python to force this data item to be a tuple
		)
		return (accum, names)
		
	elif mode == 3:
		return 1
		
	elif mode == 4:
		return [""]
		
	
def StdDev(mode, value=None, accumulator=None):

	if mode == 1:
		# Update accumulator (most common call, invoked on each sampling act)
		if accumulator is not None:
			if value is not None and type(value) is list:
				if value[0] is not None:
					accumulator[0] += 1
					accumulator[1] += value[0]
					accumulator[2] += value[0]**2
			elif value is not None and type(value) is float:
				accumulator[0] += 1
				accumulator[1] += value
				accumulator[2] += value**2
			result = True
		else:
			result = False
			
	elif mode == 2:
		# Compute result and reset accumulator (invoked on each averaging)
		if accumulator[0] is not None and accumulator[0] > 0:
			if accumulator[1] is not None and accumulator[2] is not None:
				varValue = accumulator[2] / accumulator[0] - (accumulator[1] / accumulator[0])**2
				if varValue >= 0.0:
					stdDevValue = math.sqrt(varValue)
				else:
					stdDevValue = None
			else:
				stdDevValue = None
		return ([stdDevValue], [0, 0.0] )
		
	elif mode == 0:
		# "How would you like an accumulator be made for you? And, which suffixes in result?" (invoked once, upon configuration)
		accum = [
			0,		# Number of valid values added
		    0.0,	# Running sum of valid values
		    0.0		# Running sum of valid values squared
		]
		names = (
			".StdDev",	# Comma is necessary in Python to force this data item to be a tuple
		)
		return (accum, names)
		
	elif mode == 3:
		return 1
		
	elif mode == 4:
		return [""]
		
	
def Sum(mode, value=None, accumulator=None):

	if mode == 1:
		# Update accumulator (most common call, invoked on each sampling act)
		if accumulator is not None:
			if value is not None and type(value) is list:
				if value[0] is not None:
					accumulator[0] += 1
					accumulator[1] += value[0]
			elif value is not None and type(value) is float:
				accumulator[0] += 1
				accumulator[1] += value
			result = True
		else:
			result = False
			
	elif mode == 2:
		# Compute result and reset accumulator (invoked on each averaging)
		if accumulator[0] is not None and accumulator[0] > 0:
			if accumulator[1] is not None:
				sumValues = accumulator[1]
			else:
				sumValues = None
		else:
			sumValues = None
		return ([sumValues], [0, 0.0] )
		
	elif mode == 0:
		# "How would you like an accumulator be made for you? And, which suffixes in result?" (invoked once, upon configuration)
		accum = [
			0,		# Number of valid values added
		    0.0		# Running sum of valid values
		]
		names = (
			".Sum",	# Comma is necessary in Python to force this data item to be a tuple
		)
		return (accum, names)
		
	elif mode == 3:
		return 1
		
	elif mode == 4:
		return [""]
		
	
def Min(mode, value=None, accumulator=None):

	if mode == 1:
		# Update accumulator (most common call, invoked on each sampling act)
		if accumulator is not None:
			if value is not None and type(value) is list:
				if value[0] is not None:
					accumulator[0] += 1
				if value[0] < accumulator[1]:
					accumulator[1] = value[0]
			elif value is not None and type(value) is float:
				accumulator[0] += 1
				if value < accumulator[1]:
					accumulator[1] = value
			result = True
		else:
			result = False
			
	elif mode == 2:
		# Compute result and reset accumulator (invoked on each averaging)
		if accumulator[0] is not None and accumulator[0] > 0:
			if accumulator[1] is not None:
				minValue = accumulator[1]
			else:
				minValue = None
		return ([minValue], [0, 1.0e30] )
		
	elif mode == 0:
		# "How would you like an accumulator be made for you? And, which suffixes in result?" (invoked once, upon configuration)
		accum = [
			0,		# Number of valid values added
		    1.0e30	# Minimum of valid values
		]
		names = (
			".Min",	# Comma is necessary in Python to force this data item to be a tuple
		)
		return (accum, names)
		
	elif mode == 3:
		return 1
		
	elif mode == 4:
		return [""]

	
def Max(mode, value=None, accumulator=None):

	if mode == 1:
		# Update accumulator (most common call, invoked on each sampling act)
		if accumulator is not None:
			if value is not None and type(value) is list:
				if value[0] is not None:
					accumulator[0] += 1
				if value[0] > accumulator[1]:
					accumulator[1] = value[0]
			elif value is not None and type(value) is float:
				accumulator[0] += 1
				if value > accumulator[1]:
					accumulator[1] = value
			result = True
		else:
			result = False
			
	elif mode == 2:
		# Compute result and reset accumulator (invoked on each averaging)
		if accumulator[0] is not None and accumulator[0] > 0:
			if accumulator[1] is not None:
				maxValue = accumulator[1]
			else:
				maxValue = None
		return ([maxValue], [0, -1.0e30] )
		
	elif mode == 0:
		# "How would you like an accumulator be made for you? And, which suffixes in result?" (invoked once, upon configuration)
		accum = [
			0,		# Number of valid values added
		    -1.0e30	# Maximum of valid values
		]
		names = (
			".Max",	# Comma is necessary in Python to force this data item to be a tuple
		)
		return (accum, names)
		
	elif mode == 3:
		return 1
		
	elif mode == 4:
		return [""]

	
def WindStat(mode, value=None, accumulator=None):

	if mode == 1:
		# Update accumulator (most common call, invoked on each sampling act)
		if accumulator is not None:
			if value is not None:
				if isinstance(accumulator, list) and len(accumulator) == 7:
					if isinstance(value, tuple) and len(value) == 2:
						if value[0] is not None and value[1] is not None:
							Vel = value[0]
							Dir = value[1]
							accumulator[0] += 1
							accumulator[1] += Vel
							accumulator[2] += Vel*math.sin(math.radians(Dir))
							accumulator[3] += Vel*math.cos(math.radians(Dir))
							accumulator[4] += math.sin(math.radians(Dir))
							accumulator[5] += math.cos(math.radians(Dir))
							accumulator[6] += Vel**2
							result = True
						else:
							result = False
					else:
						result = False
				else:
					result = False
		else:
			result = False
			
	elif mode == 2:
		# Compute result and reset accumulator (invoked on each averaging)
		if accumulator[0] is not None and accumulator[0] > 0:
			
			# Scalar wind speed (standard definition)
			if accumulator[1] is not None:
				scalarSpeed = accumulator[1] / accumulator[0]
			else:
				scalarSpeed = None
				
			# Vector wind speed and resultant (vector) wind direction (standard definitions)
			if accumulator[2] is not None and accumulator[3] is not None:
				vectorSpeed  = math.sqrt((accumulator[2] / accumulator[0])**2 + (accumulator[3] / accumulator[0])**2)
				resultantDir = math.degrees(math.atan2(accumulator[2] / accumulator[0], accumulator[3] / accumulator[0]))
			else:
				vectorSpeed  = None
				resultantDir = None
			
			# Unit wind direction (standard definition)
			if accumulator[4] is not None and accumulator[5] is not None:
				unitDir = math.degrees(math.atan2(accumulator[4] / accumulator[0], accumulator[5] / accumulator[0]))
			else:
				unitDir = None
			
			# Standard deviation of scalar wind speed (standard definition)
			if accumulator[1] is not None and accumulator[6] is not None:
				varVel = accumulator[6] / accumulator[0] - (accumulator[1] / accumulator[0])**2
				if varVel >= 0.0:
					stdDevVel = math.sqrt(varVel)
				else:
					stdDevVel = None
			else:
				stdDevVel = None
			
			# Standard deviation of wind direction (by Yamartino)
			if accumulator[2] is not None and accumulator[3] is not None:
				avgU = accumulator[4]/accumulator[0]
				avgV = accumulator[5]/accumulator[0]
				argSqrt = 1.0 - avgU**2 - avgV**2
				if argSqrt >= 0.0:
					eps = math.sqrt(argSqrt)
				else:
					eps = 0.0
				stdDevDir = math.degrees((1.0 + 0.1547*eps**3)*math.asin(eps))
			else:
				stdDevDir = None
				
		else:
			scalarSpeed  = None
			vectorSpeed  = None
			resultantDir = None
			unitDir      = None
			stdDevVel    = None
			stdDevDir    = None
		
		return (
			[scalarSpeed, vectorSpeed, resultantDir, unitDir, stdDevVel, stdDevDir],
			[0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		)
		
	elif mode == 0:
		# "How would you like an accumulator, and output names, be made for you?" (invoked once, upon configuration)
		accum = [
			0,		# 0 - Number of valid values added
		    0.0,	# 1 - Running sum of speeds
		    0.0,	# 2 - Running sum of Vel*sin(Dir)
		    0.0,	# 3 - Running sum of Vel*cos(Dir)
		    0.0,	# 4 - Running sum of sin(Dir)
		    0.0,	# 5 - Running sum of cos(Dir)
		    0.0		# 6 - Running sum of squared speeds
		]
		names = (
			".Scalar.Speed",
			".Vector.Speed",
			".Resultant.Dir",
			".Unit.Dir",
			".StdDev.Vel",
			".StdDev.Dir"
		)
		return (accum, names)
		
	elif mode == 3:
		return 2
		
	elif mode == 4:
		return [".Vel", ".Dir"]
