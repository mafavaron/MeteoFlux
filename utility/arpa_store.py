#!/usr/bin/python

# By: Mauri Favaron

# Preliminary warning: If you are in need of modifying this file, please
# ==================== consider to *never* use relative path, as this
#                      program will likely be started from CRONTAB, not
# from a regular program. I've just made that - at the expense of a bit
# sloppier code I'm used to.  MF

import os
import sys
import glob
import time

''' Data file intimate structure, for reference

Main file (CurData.csv)

 0 Date.Time
 1 Tot.Data
 2 Valid.Data
 3 Vel
 4 Vector.Vel
 5 Scalar.Vel
 6 Scalar.Std
 7 Dir
 8 Unit
 9 Vector.Dir
10 Yamartino.Std.Dir
11 Temp
12 Phi.Angle
13 Sigma.Phi.Angle
14 Sigma.U
15 Sigma.V
16 Sigma.W
17 Sigma.T
18 Theta,Phi
19 Psi
20 TKE
21 U.star
22 T.star
23 z.L
24 H0
25 H0.Plus.Density.Effect
26 He
27 Eff.W
28 Q
29 C
30 Fq
31 Fc

Dia file ("DiagData.csv")
 0 Date.Time
 1 Tot.Data
 2 Valid.Data
 3 N.Dir.N
 4 N.Dir.NNE
 5 N.Dir.NE
 6 N.Dir.ENE
 7 N.Dir.E
 8 N.Dir.ESE
 9 N.Dir.SE
10 N.Dir.SSE
11 N.Dir.S
12 N.Dir.SSW
13 N.Dir.SW
14 N.Dir.WSW
15 N.Dir.W
16 N.Dir.WNW
17 N.Dir.NW
18 N.Dir.NNW
19 Dominant.Dir
20 Vel
21 Dir
22 U
23 V
24 W
25 T
26 r
27 Circ.Var
28 Circ.Std
29 Range.U
30 Range.V
31 Range.W
32 Range.T
33 Nrot.Sigma2.U
34 Nrot.Sigma2.V
35 Nrot.Sigma2.W
36 Nrot.Cov.UV
37 Nrot.Cov.UW
38 Nrot.Cov.VW
39 Nrot.Cov.UT
40 Nrot.Cov.VT
41 Nrot.Cov.WT
42 Rot.Sigma2.U
43 Rot.Sigma2.V
44 Rot.Sigma2.W
45 Rot.Cov.UV
46 Rot.Cov.UW
47 Rot.Cov.VW
48 Rot.Cov.UT
49 Rot.Cov.VT
50 Rot.Cov.WT
51 Ustar.Base
52 Ustar.Extended
53 Theta
54 Phi
55 Psi
56 Eff.W
57 Q
58 C
59 

'''

sensorMap = [
	(3 , "VVS", 7015),
	(7 , "DVS", 7010),
	(21, "UST", 7040),
	(22, "TST", 7022),
	(11, "TS" , 7016),
	(24, "ZL" , 7023),
	(20, "TKE",	7024),
	(23, "H0" , 7039),
	(17, "SGT", 7021),
	(14, "SGX", 7018),
	(15, "SGY", 7019),
	(16, "SGZ", 7020)
]


def getLastLine(lineSet):

	lastLine = lineSet[len(lineSet)-1][:-1]
	return lastLine


def parseLine(line):

	blocks = line.split(",")

	dateTime = blocks[0]
	values   = [0.0]  # Placeholder, in place of time stamp, so preserving index values
	for i in range(1,len(blocks)):
		values.append(float(blocks[i]))

	try:
		timeStamp = time.strptime(dateTime, "%Y-%m-%d %H:%M:%S")
	except:
		timeStamp = None
	
	outLines = []
	validityCode = 1
	for j in range(len(sensorMap)):
		mapDetails = sensorMap[j]
		quantityIndex = mapDetails[0]
		quantityCode  = mapDetails[2]
		outMessage = "%s,%d,%f,%d" % (dateTime, quantityCode, values[quantityIndex], validityCode)
		outLines.append(outMessage)

	return outLines


if __name__ == "__main__":

	# Get data file

	try:
		dataFile = open("/mnt/ramdisk/CurData.csv", "r")
		data = dataFile.readlines()
		dataFile.close()
	except:
		print "No data file, aborting execution"
		sys.exit(1)

	# Get last line from files: this is the one we'll work on
	actualData = getLastLine(data)

	# Parse data lines
	linesToWrite = parseLine(actualData)
	for i in range(len(linesToWrite)):
		print linesToWrite[i]

