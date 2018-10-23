#!/usr/bin/python

# Base functions
#
# Copyright 2012 by Servizi Territorio srl
#                   All rights reserved
#

def closest(val, vector):
	# Find the closest element in vector

	dist = [abs(vector[i] - val) for i in range(len(vector))]
	idxMin = 0
	min_val = 1000000000
	for i in range(len(dist)):
		if dist[i] < min_val:
			min_val = dist[i]
			idxMin = i
	return vector[idxMin]
	

