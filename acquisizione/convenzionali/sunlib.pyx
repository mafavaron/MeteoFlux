# sunlib.py - A Python library providing useful quantities related
# to solar position.
#
# Implementation closely follows the algorithm stored in the "old NOAA
# web solar calculator page" - in fact is a translation of its most
# significant parts, with provisions for using regular longitude
# instead of "anti-longitude" as in original NOAA page.
#
# By: Mauri Favaron - Servizi Territorio srl

import datetime
import os
import sys
import math

# Check whether leap (1) or even (0) year
cdef int isLeapYear(int yr):
	
	return ((yr % 4 == 0 and yr % 100 != 0) or yr % 400 == 0)


# Julian day, according to NOAA conventions
cdef double calcJD(int year, int month, int day):
	
	cdef double A
	cdef double B
	cdef double jd
	
	if month <= 2:
		year -= 1
		month += 12
	A = math.floor(year/100)
	B = 2 - A + math.floor(A/4)
	jd = math.floor(365.25*(year + 4716)) + math.floor(30.6001*(month+1)) + day + B - 1524.5

	return jd


# Convert between Julian day and Julian century

cdef double calcTimeJulianCent(double jd):

	cdef double T
	
	T = (jd - 2451545.0)/36525.0
	
	return T


cdef double calcJDFromJulianCent(double t):
	
	cdef double JD
	
	JD = t * 36525.0 + 2451545.0
	return JD


############################################
# Auxiliary quantities from Julian century #
############################################

# Compute Sun's geometric mean longitude from t in julian cents
cdef double calcGeomMeanLongSun(double t):
	
	cdef double L0

	L0 = 280.46646 + t * (36000.76983 + 0.0003032 * t)
	while(L0 > 360.0):
		L0 -= 360.0
	while(L0 < 0.0):
		L0 += 360.0
	return L0		# in degrees


# Compute Sun's geometric mean anomaly from t in julian cents
cdef double calcGeomMeanAnomalySun(double t):

	cdef double M
	
	M = 357.52911 + t * (35999.05029 - 0.0001537 * t)
	return M		# in degrees


# Compute Earth's orbit eccentricity
cdef double calcEccentricityEarthOrbit(double t):

	cdef double e
	
	e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
	return e		# unitless


# Compute the equation of Sun center
cdef double calcSunEqOfCenter(double t):
	
	cdef double m, mrad, sinm, sin2m, sin3m, C

	m = calcGeomMeanAnomalySun(t)
	mrad = math.radians(m)
	sinm = math.sin(mrad)
	sin2m = math.sin(mrad+mrad)
	sin3m = math.sin(mrad+mrad+mrad)
	C = sinm * (1.914602 - t * (0.004817 + 0.000014 * t)) + sin2m * (0.019993 - 0.000101 * t) + sin3m * 0.000289

	return C		# in degrees


# Compute the Sun's true longitude
cdef double calcSunTrueLong(double t):
	
	cdef double l0, c, O

	l0 = calcGeomMeanLongSun(t)
	c = calcSunEqOfCenter(t)
	O = l0 + c
	return O		# in degrees


# Compute the true anomaly of Sun
cdef double calcSunTrueAnomaly(double t):
	
	cdef double m, c, v

	m = calcGeomMeanAnomalySun(t)
	c = calcSunEqOfCenter(t)
	v = m + c
	return v		# in degrees


# Calculate the distance to the Sun in AU
cdef double calcSunRadVector(double t):
	
	cdef double v, e, R

	v = calcSunTrueAnomaly(t)
	e = calcEccentricityEarthOrbit(t)

	R = (1.000001018 * (1 - e * e)) / (1 + e * math.cos(math.radians(v)))
	return R			# in AUs


# Compute the Sun's apparent longitude
cdef double calcSunApparentLong(double t):

	cdef double o, omega, lmbd
	
	o = calcSunTrueLong(t)

	omega = 125.04 - 1934.136 * t
	lmbd  = o - 0.00569 - 0.00478 * math.sin(math.radians(omega))
	return lmbd			# in degrees


# Compute mean obliquity of the ecliptic
cdef double calcMeanObliquityOfEcliptic(double t):
	
	cdef double seconds, e0

	seconds = 21.448 - t*(46.8150 + t*(0.00059 - t*0.001813))
	e0 = 23.0 + (26.0 + (seconds/60.0))/60.0
	return e0		# In degrees


# Compute ecliptic obliquity correction
cdef double calcObliquityCorrection(double t):
	
	cdef double e0, omega, e

	e0 = calcMeanObliquityOfEcliptic(t)
	omega = 125.04 - 1934.136 * t
	e = e0 + 0.00256 * math.cos(math.radians(omega))
	return e		# in degrees


# Compute Sun's right ascension
cdef double calcSunRtAscension(double t):
	
	cdef double e, lmbd, tatanum, tanadenom, alpha

	e = calcObliquityCorrection(t)
	lmbd = calcSunApparentLong(t)
	tananum = (math.cos(math.radians(e)) * math.sin(math.radians(lmbd)))
	tanadenom = (math.cos(math.radians(lmbd)))
	alpha = math.degrees(math.atan2(tananum, tanadenom))
	return alpha		# in degrees


# Compute Sun declination
cdef double calcSunDeclination(double t):
	
	cdef double e, lmbd, sint, theta

	e = calcObliquityCorrection(t)
	lmbd = calcSunApparentLong(t)
	sint = math.sin(math.radians(e)) * math.sin(math.radians(lmbd))
	theta = math.degrees(math.asin(sint))
	return theta		# in degrees


# Compute the Equation of Time
cdef double calcEquationOfTime(double t):
	
	cdef double epsilon, l0, e, m, y, sin2l0, cos2l0, sinm, sin4l0, sin2m, Etime

	epsilon = calcObliquityCorrection(t)
	l0 = calcGeomMeanLongSun(t)
	e = calcEccentricityEarthOrbit(t)
	m = calcGeomMeanAnomalySun(t)
	y = math.tan(math.radians(epsilon)/2.0)
	y *= y
	sin2l0 = math.sin(2.0 * math.radians(l0))
	sinm   = math.sin(math.radians(m))
	cos2l0 = math.cos(2.0 * math.radians(l0))
	sin4l0 = math.sin(4.0 * math.radians(l0))
	sin2m  = math.sin(2.0 * math.radians(m))
	Etime = y * sin2l0 - 2.0 * e * sinm + 4.0 * e * y * sinm * cos2l0 - 0.5 * y * y * sin4l0 - 1.25 * e * e * sin2m
	Etime = math.degrees(Etime)*4.0	# in minutes of time
	return Etime


# Estimate refractive solar elevation
cpdef double calcSolarElevation(str sDateTime, double latitude, double longitude, double zone):

	# Get date and time information from time stamp string			
	cdef int ss, mm, hh, yy, mo, dy, doy
	if zone > 12 or zone < -12.5:
		zone = 0.0
	dateTime = datetime.datetime.strptime(sDateTime, "%Y-%m-%d %H:%M:%S")
	tm = dateTime.timetuple()
	ss = tm.tm_sec
	mm = tm.tm_min
	hh = tm.tm_hour
	yy = tm.tm_year
	mo = tm.tm_mon
	dy = tm.tm_mday
	doy = tm.tm_yday

	# Compute UTC hour to be used in further calculations, and
	# other time-related quantities
	cdef double timenow, JD, T, solarDec, Etime
	timenow = hh + mm/60 + ss/3600 - zone
	JD = calcJD(yy, mo, dy)
	T = calcTimeJulianCent(JD + timenow/24.0)
	solarDec = calcSunDeclination(T)
	Etime = calcEquationOfTime(T)

	# Compute solar time
	cdef double solarTimeFix, trueSolarTime
	solarTimeFix = Etime - 4.0 * longitude + 60.0 * zone
	trueSolarTime = hh * 60.0 + mm + ss/60.0 + solarTimeFix		# in minutes
	while trueSolarTime > 1440:
		trueSolarTime -= 1440

	# Compute hour angle (in degrees and radians)
	cdef double hourAngle, haRad
	hourAngle = trueSolarTime / 4.0 - 180.0
	if hourAngle < -180:
		hourAngle += 360.0
	haRad = math.radians(hourAngle)

	# Compute solar zenith
	cdef double csz, zenith
	csz = math.sin(math.radians(latitude)) * math.sin(math.radians(solarDec)) + math.cos(math.radians(latitude)) * math.cos(math.radians(solarDec)) * math.cos(haRad)
	if csz > 1.0:
		csz = 1.0
	elif csz < -1.0:
		csz = -1.0 
	zenith = math.degrees(math.acos(csz))

	# Compute and apply refractive correction
	cdef double exoatmElevation, refractionCorrection, te, solarZen, solarElevation
	cdef str timeType
	exoatmElevation = 90.0 - zenith
	if exoatmElevation > 85.0:
		refractionCorrection = 0.0
	else:
		te = math.tan(math.radians(exoatmElevation))
		if exoatmElevation > 5.0:
			refractionCorrection = 58.1 / te - 0.07 / (te*te*te) + 0.000086 / (te*te*te*te*te)
		elif exoatmElevation > -0.575:
			refractionCorrection = 1735.0 + exoatmElevation * (-518.2 + exoatmElevation * (103.4 + exoatmElevation * (-12.79 + exoatmElevation * 0.711) ) )
		else:
			refractionCorrection = -20.774 / te
		refractionCorrection = refractionCorrection / 3600.0
	solarZen = zenith - refractionCorrection
	solarElevation = 90 - solarZen
	
	return solarElevation

#####################
# Other auxiliaries #
#####################

# Compute the hour angle for the given location, decl, and time of day
cdef double calcHourAngle(double time, double longitude, double eqtime):
	
	cdef double result

	result = (15.0*(time - (longitude/15.0) - (eqtime/60.0)))		# in degrees
	return result


############################
# Main calculation routine #
############################

cpdef sun(str sDateTime, double latitude, double longitude, double zone):

	# Validate horizontal position
	if latitude >= -90. and latitude < -89.8:
		latitude = -89.8
	if latitude <= 90. and latitude > 89.8:
		latitude = 89.8

	# Get date and time information from time stamp string			
	cdef int ss, mm, hh, yy, mo, dy, doy
	if zone > 12 or zone < -12.5:
		zone = 0.0
	dateTime = datetime.datetime.strptime(sDateTime, "%Y-%m-%d %H:%M:%S")
	tm = dateTime.timetuple()
	ss = tm.tm_sec
	mm = tm.tm_min
	hh = tm.tm_hour
	yy = tm.tm_year
	mo = tm.tm_mon
	dy = tm.tm_mday
	doy = tm.tm_yday

	# Compute UTC hour to be used in further calculations, and
	# other time-related quantities
	cdef double timenow, JD, T, L0, M, e, C, O, v, R, lmbd, epsilon0, epsilon, alpha, solarDec, Etime
	timenow = hh + mm/60 + ss/3600 - zone
	JD = calcJD(yy, mo, dy)
	T = calcTimeJulianCent(JD + timenow/24.0)
	L0 = calcGeomMeanLongSun(T)
	M = calcGeomMeanAnomalySun(T)
	e = calcEccentricityEarthOrbit(T)
	C = calcSunEqOfCenter(T)
	O = calcSunTrueLong(T)
	v = calcSunTrueAnomaly(T)
	R = calcSunRadVector(T)
	lmbd = calcSunApparentLong(T)
	epsilon0 = calcMeanObliquityOfEcliptic(T)
	epsilon = calcObliquityCorrection(T)
	alpha = calcSunRtAscension(T)
	solarDec = calcSunDeclination(T)
	Etime = calcEquationOfTime(T)

	# Compute solar time
	cdef double solarTimeFix, trueSolarTime
	solarTimeFix = Etime - 4.0 * longitude + 60.0 * zone
	trueSolarTime = hh * 60.0 + mm + ss/60.0 + solarTimeFix		# in minutes
	while trueSolarTime > 1440:
		trueSolarTime -= 1440

	# Compute hour angle (in degrees and radians)
	cdef double hourAngle, haRad
	hourAngle = trueSolarTime / 4.0 - 180.0
	if hourAngle < -180:
		hourAngle += 360.0
	haRad = math.radians(hourAngle)

	# Compute solar zenith
	cdef double csz, zenith, azDenom, azRad
	csz = math.sin(math.radians(latitude)) * math.sin(math.radians(solarDec)) + math.cos(math.radians(latitude)) * math.cos(math.radians(solarDec)) * math.cos(haRad)
	if csz > 1.0:
		csz = 1.0
	elif csz < -1.0:
		csz = -1.0 
	zenith = math.degrees(math.acos(csz))
	azDenom = ( math.cos(math.radians(latitude)) * math.sin(math.radians(zenith)) )
	if math.fabs(azDenom) > 0.001:
		azRad = (( math.sin(math.radians(latitude)) * math.cos(math.radians(zenith)) ) - math.sin(math.radians(solarDec))) / azDenom
		if math.fabs(azRad) > 1.0:
			if azRad < 0:
				azRad = -1.0
			else:
				azRad = 1.0
		azimuth = 180.0 - math.degrees(math.acos(azRad))
		if hourAngle > 0.0:
			azimuth = -azimuth
	else:
		if latitude > 0.0:
			azimuth = 180.0
		else:
			azimuth = 0.0
	if azimuth < 0.0:
		azimuth += 360.0

	# Compute and apply refractive correction
	cdef double exoatmElevation, refractionCorrection, te, solarZen, solarElevation
	cdef str timeType
	exoatmElevation = 90.0 - zenith
	if exoatmElevation > 85.0:
		refractionCorrection = 0.0
	else:
		te = math.tan(math.radians(exoatmElevation))
		if exoatmElevation > 5.0:
			refractionCorrection = 58.1 / te - 0.07 / (te*te*te) + 0.000086 / (te*te*te*te*te)
		elif exoatmElevation > -0.575:
			refractionCorrection = 1735.0 + exoatmElevation * (-518.2 + exoatmElevation * (103.4 + exoatmElevation * (-12.79 + exoatmElevation * 0.711) ) )
		else:
			refractionCorrection = -20.774 / te
		refractionCorrection = refractionCorrection / 3600.0
	solarZen = zenith - refractionCorrection
	solarElevation = 90 - solarZen
	if solarZen < 90.0:
		timeType = "Daytime"
	elif solarZen < 108.0:
		timeType = "Astronomical twilight"
	else:
		timeType = "Nighttime"
		
	# Provide output
	return (
		JD,					# Julian day
		doy,				# Day in year
		T,					# Julian century
		L0,					# Geometrical mean longitude of Sun
		M,					# Geometrical mean anomaly of Sun
		e,					# Earth orbit eccentricity
		C,					# Equation of Sun center
		O,					# Sun true longitude
		v,					# Sun true anomaly
		R,					# Earth-Sun radial vector (AU)
		lmbd,				# Sun apparent longitude
		epsilon0,			# Mean ecliptic obliquity
		epsilon,			# Ecliptic obliquity correction
		alpha,				# Sun right ascension
		solarDec,			# Sun declination
		Etime,				# Equation of time
		trueSolarTime,		# Solar time (minutes)
		hourAngle,			# Hour angle
		zenith,				# Solar zenith (no refractive correction)
		azimuth,			# Solar azimuth
		exoatmElevation,	# Solar elevation as visible outside the Earth atmosphere
		solarZen,			# Solar zenith with refractive correction
		solarElevation,		# Solar elevation with refractive correction
		timeType			# Type of time (Daytime, Astronomical twilight, Nighttime)
	)
