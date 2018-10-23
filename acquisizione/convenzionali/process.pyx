#!/usr/bin/python

# Data processing and related "business logics" (in the context of data acquisition systems)
#
# Copyright 2012 by Servizi Territorio srl
#                   All rights reserved

# Helpers, typically used in initialization phase

def computeLinearConversion(readingA, readingB, physicalA, physicalB):
	# Compute multiplier and offset of a linear scaling, given two electrical
	# (e.g. voltage) readings and their corresponding physical unit values.

	if abs(readingA - readingB) > 0.001 and abs(physicalA - physicalB) > 0.001:
		multiplier = (physicalA - physicalB)/(readingA - readingB)
		offset     = (physicalB*readingA - physicalA*readingB)/(readingA - readingB)
	else:
		multiplier = None
		offset     = None
		
	return (multiplier, offset)


# Conversion from raw reading to "physical units" (aka "engineering units" - really the same thing)

def toPhysicalUnits(value, multiplier=1.0, offset=0.0):
	# Linear scaling of an observed electrical quantity to physical units
	
	if value is not None:
		result = value * multiplier + offset
	else:
		result = None
		
	return result
	

def toState(value):
	
	if value is not None:
		
		state = (value != 0)
		
	else:
	
		state = None
		
	return(state)



# Test function

if __name__ == "__MAIN__":
	
	(multiplier, offset) = computeLinearConversion(0, 50000, 0, 1000)
	print multiplier
	print offset
	
