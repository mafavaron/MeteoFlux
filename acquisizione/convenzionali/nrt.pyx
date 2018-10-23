# nrt.py - Near real time related functions.
#
# Copyright 2012 by Servizi Territorio srl
#                   All rights reserved
#

import time
import calendar


def waitUntilNext(timeStep, granularity):
	# Wait until next integer multiple to 'timeStep', up to accuracy as defined by 'granularity'.
	# Normally, 'granularity' is one tenth the 'timeStep'. The smaller 'granularity', the higher
	# the CPU load.
	
	# Get current time
	t = time.time()
	
	# Generate the time which is:
	# - an integer multiple of 'timeStep'
	# - strictly larger than 't'
	tq = t // timeStep	# "floor division" used instead of normal division
	tTarget = tq * timeStep
	while tTarget <= t:
		tTarget = tTarget + timeStep
		
	# Wait until the target time has been reached or exceeded
	while time.time() < tTarget:
		time.sleep(granularity)
		
	return (tTarget, time.time())
	
