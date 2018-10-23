import math
import numpy as np
import datetime
import sunlib

###################################
# Psychrometry and related things #
###################################

# Water vapor pressure given dry and wet bulb temperatures
# and pressure.
#
#     Input: Ta = dry-bulb air temperature (K)
#            Tw = wet-bulb air temperature (K)
#            Pa = air pressure (hPa)
#
#     Output: EAS_1 = actual vapor pression (hPa)
#
cpdef double EAS_1(double Ta, double Tw, double Pa):
	
	cdef double e

	e = ESAT(Tw) - 0.00066*(1.+0.00115*(Tw-273.15))*Pa*(Ta-Tw)

	return e
	

# Water vapor pressure given dew point temperature.
#
#     Input: Tdew = dew point temperature (K)
#
#     Output: EAS_2 = actual vapor pression (hPa)
#
cpdef double EAS_2(double Tdew):
	
	cdef double e
	
	e = ESAT(Tdew)
	
	return e
	
	
# Precipitable water given water vapor pressure
#
#	Input:
#
#		Ea		Actual water vapor pressure (hPa)
#
#		Pa		Actual pressure at measurement altitude (i.e. not reduced to mean sea level) (hPa)
#
#	Output:
#
#		W		Precipitable water (mm)
#
cpdef double PrecipitableWater(double Ea, double Pa):
	
	cdef double W
	
	W = 0.0014*Ea*Pa + 2.21
	
	return W


# Relative humidity, given actual and saturation vapor pressures.
#
#     Input : e    = Existing vapor pressure (hPa)
#             es   = saturation vapor pression (hPa)
#
#     Output: EREL = relative humidity (%)
#
cpdef double EREL(e, es):
	
	cdef double er
	
	er = 100. * e / es
	
	return er


# Saturation water vapor pressure given air temperature.
#
#     Input: Ta = air temperature (Kelvin)
#
#     Output: ESAT = saturation vapor pression (mb)
#                    -9999. if error
#
cpdef double ESAT(double Ta):
	
	cdef double es
	
	if Ta > 273.15:
		es = math.exp(-6763.6/Ta-4.9283*math.log(Ta)+54.23)
	else:
		es = math.exp(-6141.0/T+24.3)
	
	return es


# Specific humidity given air and water vapor pressures
#
#     Input: Pa = air pressure (hPa)
#            e  = vapor pressure (hPa)
#
#     Output: HUMID = specific humidity (g-water/g-air)
#
cpdef double HUMID(double Pa, double e):
	
	cdef double h
	
	h = 0.622 * e / Pa
	
	return h


# Virtual temperature given air temperature and mixing ratio.
#
#     Input: Ta = air temperature (K)
#            W  = mixing ratio (dimensionless)
#
#     Output: TEMPV = virtual temperature (K)
#
cpdef double TEMPV(double Ta, double W):
	
	cdef double tv
	
	tv = Ta * (1.+1.609*W)/(1.+W)

	return tv


# Potential temperature, given air temperature and pressure.
#
#     Input: Ta = reference air temperature (K)
#            Pa = air pressure (hPa)
#
#     Output: TPOT_1 = potential temperature (K)
#
cpdef double TPOT_1(double Ta, double Pa):
	
	cdef double tp

	tp = Ta * (1000./Pa)**0.286

	return tp


# Potential temperature given air temperature and station altitude.
#
#     Input: T  = reference air temperature (Kelvin)
#            z  = heigth (m)
#
#     Output: TPOT_2 = potential temperature (Kelvin)
#
cpdef double TPOT_2(double Ta, double z):

	cdef double tp

	tp = Ta + 0.0098 * z

	return tp


# Wet bulb temperature given dry bulb temperature and relative humidity.
#
#     Input: Ta   = dry bulb air temperature (K)
#            RelH = relative humidity (%)
#            Pa   = air pressure (hPa; optional, with default 1013)
#
#     Output: TWET = wet-bulb temperature (Celsius)
#
cpdef double TWET(double Ta, double RelH, double Pa = 1013.0):

	cdef double tw, e1, esatt, ur, twt
	
	tw = Ta

	while True:
		e1    = EAS_1(Ta, tw, Pa)
		esatt = ESAT(Ta)
		ur    = e1/esatt*100.
		if ur > RelH:
			tw -= 1.
		else:
			break

	while True:
		e1 = EAS_1(Ta, tw, Pa)
		esatt= ESAT(Ta)
		ur = e1/esatt*100.
		if ur < (RelH-RelH/10000.):
			tw += 0.001
		else:
			break

	return tw


# Air specific volume given temperature, relative humidity and pressure.
#
#     Input: Ta   = air temperature (K)
#            RelH = relative humidity (%)
#            Pa   = air pressure (hPa)
#
#     Output: VSPEC_AIR = specific volume (mc/kg-dry air)
#
cpdef double VSPEC_AIR(double Ta, double RelH, double Pa):

	cdef double v1, v2, vs
	
	v1 = 22.4*Ta/ 29.3/273.15
	v2 = VSPEC_SAT(Ta,Pa)
	vs = v1 + (v2-v1)*RelH/100.
	
	return vs


# Air specific saturation volume given temperature and pressure.
#
#     Input: Ta   = air temperature (K)
#            Pa   = air pressure (hPa)
#
#     Output: VSPEC_SAT = specific volume at saturation (mc/kg-dry air)
#
cpdef  VSPEC_SAT(Ta, Pa):

	cdef double hs, vs
	
	hs = 0.622*ESAT(Ta)/(Pa-ESAT(Ta))
	vs = 22.4*Ta/273.15*(1./29.3+1/18.*hs)

	return vs


# Mixing ratio given water vapor pressure and air pressure.
#
#     Input: Pa = air pressure (hPa)
#            E  = vapor pressure (hPa)
#
#     Output: WMIX = mixing ratio (g-water/g-air)
#
cpdef double WMIX(double Pa, double E):

	cdef double wm
	wm = 0.622 * E / (Pa - E)
	return wm


##########################################################
# Solar global and net radiation, and related quantities #
##########################################################

# MPDA estimate of global solar radiation
#
#     Input:
#             C              = cloud cover (0..1)
#             solarElevation = solar elevation angle
#     Output:
#             Rg = global radiation  (W/m2)
#
cpdef double GLOBALRAD_M(double C, double solarElevation):

	cdef double a1,a2,b1,b2 = 990., -30., -0.75, 3.4
	cdef double aa1 = 1098.
	cdef double sinmin, Rg, sin_psi

	sin_psi = math.sin(math.radians(solarElevation))
	sinmin = -a2/a1
	if sin_psi >= sinmin:
		Rg = ( a1 * sin_psi + a2 ) * ( 1. + b1 * math.pow(C,b2) )
	else:
		Rg = 0.
			
	return Rg


# Haurwitz 1945 estimate of global solar radiation
#
#     Input:
#             C              = cloud cover (0..1)
#             solarElevation = solar elevation angle
#     Output:
#             Rg = global radiation  (W/m2)
#
cpdef double GLOBALRAD_H45(cloud,solarElevation):

	cdef double a1,a2,b1,b2 = 990., -30., -0.75, 3.4
	cdef double aa1 = 1098.
	cdef double sinmin, Rg, sin_psi

	sin_psi = math.sin(math.radians(solarElevation))
	sinmin = -a2/a1
	if sin_psi >= sinmin:
		Rg = ( aa1 * sin_psi * math.exp(-0.057/sin_psi) ) * (1. + b1 * cloud**b2 )
	else:
		Rg = 0.
			
	return Rg


# MPDA estimate of net radiation.
#
#     Input:
#             C   = cloud cover (0..1)
#             Ta  = temperature (K)
#             alb = albedo (0..1)
#             Rg  = global radiation (W/m2)
#     Output:
#             NETRAD = net radiation (W/m2)
#
cpdef double NETRAD(C, Ta, alb, Rg):

	cdef double c1,c2,c3 = 5.31e-13, 60., 0.12
	cdef double sigma = 5.67e-08
	cdef double Rn

	Rn = ( (1-alb) * Rg + (c1 * Ta**6. + c2*C - sigma * Ta**4) )/( 1. + c3 )

	return Rn


# Albedo estimation.
#
#     Input:
#             jd    =  Julian day
#             land  =  ground tipology (1..8)
#             isnow =  snow presence(1)/snow absence(0)
#             iemisph= 0 for the North emisphere
#                    = 1 for the South emisphere
#
#     Output:
#             albedo_0 = transmitted solar radiation fraction (0..1)
#                        reflected by ground.
#
#
#     ground tipology                spring  summer  autumn  winter
#     1- water (sea/lake)              0.12    0.10    0.14    0.20
#     2- deciduous forest              0.12    0.12    0.12    0.50
#     3- coniferous forest             0.12    0.12    0.12    0.35
#     4- swamp                         0.12    0.14    0.16    0.30
#     5- cultivated land               0.14    0.20    0.18    0.60
#     6- grass land                    0.18    0.18    0.20    0.60
#     7- urban                         0.14    0.16    0.18    0.35
#     8- desert shrubland              0.30    0.28    0.28    0.45
#
#     N.B. During winter: with mantle of snow, winter data will be used
#                      without mantle of snow, autumn data will be used
#
cpdef double ALBEDO(int doy, double solarElevation, int land, int isnow, int iemisph):

	cdef double alb, c1, c2
	
	values = np.matrix([
		[0.12,0.12,0.12,0.12,0.14,0.18,0.14,0.30],
		[0.10,0.12,0.12,0.14,0.20,0.18,0.16,0.28],
		[0.14,0.12,0.12,0.16,0.18,0.20,0.18,0.28],
		[0.20,0.50,0.35,0.30,0.60,0.60,0.35,0.45]
	])

	# Compute rough, table-based approximation to albedo
	
	if iemisph == 0:	# Northern
		istag=3
		if doy >= 80 and doy < 172:
			istag=1
		elif doy >= 172 and doy < 264:
			istag=2
		elif isnow == 1:
			istag=4
	else:				# Southern
		istag=3
		if doy >= 355 or  doy < 80:
			istag=2
		elif doy >= 264 and doy < 355:
			istag=1
		elif isnow == 1:
			istag=4

	alb = values[land-1,istag-1]
	
	# Apply correction for low solar elevation angles
	
	if solarElevation < 30.:
		c1 =  1.-albedo_e
		c2 = -0.5 * c1*c1
		alb += c1 * math.exp(-0.1 * solarElevation + c2)

	return alb


# MPDA estimate of Cloud cover
#     observed temperature, global and net radiation.
#     Note: Net radiation is measured by a Net radiometer
#           Global Radiation is measured by a Pyranometer (short wawe,
#           solar radiation only)
#           In nigh-time hours must be: Rg=0.   and it will result albedo=0.
#
#     Input:   Rg  = Global Radiazione by a Pyranometer
#              Rn  = Net radiation by a Net Radiometer
#              sin_psi= sin of sola elevation (see S_EL_ANG routine)
#              T    = air temperature (Kelvin)
#
#     Output:  CLOUD_RGN = total cloud cover (0..1)
#
#     A particular situation can occour when Rn is not available
#      In this case:   set input Rn = -9999.
#                      Results.......
#                       a) cloud_rgn is available only in day-time
#                             (-9999. in night-time)
#
#    WARNING: During transitional hours (i.e. around sun_rise and
#             sun_set hours), the cloud cover estimate could often be poor.
#             Particularly in these hours the averaging time for Rg, Rn
#             and sin_psi values must be at least 1 hour.
#
cpdef double CLOUD_RGN_M(double Rg, double Rn, double solarElevation, double T):

	cdef double a1,a2,b1,b2 = 990., -30., -0.75, 3.4
	cdef double aa1 = 1098.
	cdef double c1,c2,c3 = 5.31e-13, 60., 0.12
	cdef double sigma = 5.67e-08
	
	cdef double cloud_tot, c1t6, sinpsimin, rgmax, sin_psi

	sin_psi = math.sin(math.radians(solarElevation))
	cloud_tot = -9999.
	c1t6 = c1 * T**6 - sigma * T**4
	sinpsimin = - a2 / a1

	if sin_psi > sinpsimin:
		# Day-time
		rgmax = a1 * sin_psi + a2
		if Rg >= rgmax:
			cloud_tot = 0.
		else:
			cloud_tot = math.pow(1./b1 * (Rg/rgmax-1.), 1./b2)
	else:
		# Night-time
		if rn > -9990.:
			cloud_tot = ( (1.+c3) * Rn - c1T6 ) / c2
		else:
			cloud_tot = -9999.

	if cloud_tot > 1.:
		cloud_tot = 1.
	if cloud_tot < 0.:
		cloud_tot = 0.
	return cloud_tot


# Haurwitz 1945 estimate of Cloud cover
#     observed temperature, global and net radiation.
#     Note: Net radiation is measured by a Net radiometer
#           Global Radiation is measured by a Pyranometer (short wawe,
#           solar radiation only)
#           In nigh-time hours must be: Rg=0.   and it will result albedo=0.
#
#     Input:   Rg  = Global Radiazione by a Pyranometer
#              Rn  = Net radiation by a Net Radiometer
#              sin_psi= sin of sola elevation (see S_EL_ANG routine)
#              T    = air temperature (Kelvin)
#
#     Output:  CLOUD_RGN = total cloud cover (0..1)
#
#     A particular situation can occour when Rn is not available
#      In this case:   set input Rn = -9999.
#                      Results.......
#                       a) cloud_rgn is available only in day-time
#                             (-9999. in night-time)
#
#    WARNING: During transitional hours (i.e. around sun_rise and
#             sun_set hours), the cloud cover estimate could often be poor.
#             Particularly in these hours the averaging time for Rg, Rn
#             and sin_psi values must be at least 1 hour.
#
cpdef double CLOUD_RGN_H45(double Rg, double Rn, double solarElevation, double T):

	cdef double a1,a2,b1,b2 = 990., -30., -0.75, 3.4
	cdef double aa1 = 1098.
	cdef double c1,c2,c3 = 5.31e-13, 60., 0.12
	cdef double sigma = 5.67e-08
	
	cdef double cloud_tot, c1t6, sinpsimin, rgmax, sin_psi

	sin_psi = math.sin(math.radians(solarElevation))
	cloud_tot = -9999.
	c1t6 = c1 * T**6 - sigma * T**4
	sinpsimin = - a2 / a1

	if sin_psi > sinpsimin:
		# Day-time
		rgmax = aa1*sin_psi*exp(-0.057/sin_psi)
		if Rg >= rgmax:
			cloud_tot = 0.
		else:
			cloud_tot = math.pow(1./b1 * (Rg/rgmax-1.), 1./b2)
	else:
		# Night-time
		if rn > -9990.:
			cloud_tot = ( (1.+c3) * Rn - c1T6 ) / c2
		else:
			cloud_tot = -9999.

	if cloud_tot > 1.:
		cloud_tot = 1.
	if cloud_tot < 0.:
		cloud_tot = 0.
	return cloud_tot


# Estimation of clear sky radiation by the simplified method
#
# Input:
#
#	Ra		Extraterrestrial radiation (W/m2)
#
#	z		Site elevation above mean sea level (m)
#
# Output:
#
#	Rso		Clear sky radiation (W/m2)
#
cpdef double ClearSkyRg_Simple(double Ra, double z):
	
	cdef double Rso
	
	Rso = Ra * (0.75 + 2.0e-5*z)
	
	return Rso
	

# Estimation of clear sky radiation by the simplified method
#
# Input:
#
#	Ra		Extraterrestrial radiation (W/m2)
#
#	Pa		Local pressure, that is, pressure not reduced to mean sea level (hPa)
#
#	Temp	Local temperature (Celsius degrees)
#
#	Hrel	Relative humidity (%)
#
#	Kt		Turbidity coefficient (dimensionless, 0 excluded to 1 included;
#			value 1 corresponds to perfectly clean air; for extremelyturbid,
#			dusty or polluted air 0.5 may be assumed; recommended value lacking
#			better data: 1, the default)
#
# Output:
#
#	Rso		Clear sky radiation (W/m2)
#
cpdef double ClearSkyRg_Accurate(str timeStamp, double averagingPeriod, double zone, double lat, double lon, double Pa, double Temp, double Hrel, double Kt=1.0):
	
	cdef double Rso, Kb, Kd, Ra
	cdef double beta, sinBeta, W
	cdef double e, es, Ta
	
	# Estimate extraterrestrial radiation
	Ra = ExtraterrestrialRadiation(timeStamp, averagingPeriod, zone, lat, lon)
	
	# Estimate the amount of precipitable water
	Ta = Temp + 273.15
	es = ESAT(Ta)
	e  = Hrel*es/100
	W  = PrecipitableWater(e, Pa)
	
	# Compute solar elevation (refractive correction applied)
	solarElevation = sunlib.calcSolarElevation(sTimeStamp, lat, lon, zone)
	sinBeta = math.sin(math.radians(solarElevation))
	
	# Estimate the clearness index for direct beam radiation
	Kb = 0.98*math.exp(-0.000149*Pa/(Kt*sinBeta) - 0.075*math.pow(W/sinBeta, 0.4))
	
	# Estimate the transmissivity index for diffuse radiation
	if Kb >= 0.15:
		Kd = 0.35 - 0.36*Kb
	else:
		Kd = 0.18 + 0.82*Kb
	
	# Last, estimate clear-sky radiation
	Rso = Ra * (Kb + Kd)
	
	return Rso
	
	
# Accurate estimate of extraterrestrial solar radiation
#
# Input:
#
#	timeStamp			String, in form "YYYY-MM-DD HH:MM:SS" indicating time on *beginning* of averaging period
#						(beware: many Italian weather station use a time stamp on *end* of averaging period:
#						if so, subtract one hour)
#
#	averagingPeriod		Length of averaging period (s)
#
#	zone				Time zone number (hours, positive Eastwards, in range -12 to 12)
#
#	lat					Local latitude (degrees, positive northwards)
#
#	lon					Local longitude (degrees, positive eastwards)
#
# Output:
#
#	ra					Extraterrestrial radiation (W/m2)
#
cpdef double ExtraterrestrialRadiation(str timeStamp, double averagingPeriod, double zone, double lat, double lon):
	
	cdef int ss, mm, hh, yy, mo, dy, doy
	cdef double dr, ra
	cdef double omega, omega1, omega2, omegaS
	cdef double SOLAR_CONSTANT = 1361.5		# W/m2
	cdef double timenow, JD, T, t, Sc, b, t1

	# Transform time stamp to useful quantities
	dateTime = datetime.datetime.strptime(sDateTime, "%Y-%m-%d %H:%M:%S")
	tm = dateTime.timetuple()
	ss = tm.tm_sec
	mm = tm.tm_min
	hh = tm.tm_hour
	yy = tm.tm_year
	mo = tm.tm_mon
	dy = tm.tm_mday
	doy = tm.tm_yday

	# Compute the solar declination
	timenow = hh + mm/60 + ss/3600 - zone
	JD = sunlib.calcJD(yy, mo, dy)
	T = sunlib.calcTimeJulianCent(JD + timenow/24.0)
	solarDeclination = sunlib.calcSunDeclination(T)
	
	# Inverse squared relative distance factor for Sun-Earth
	dr = 1.0 + 0.033*math.cos(2*math.pi*doy/365.0)
	
	# Calculate geographical positioning parameters (with a "-" sign for longitudes, according to ASCE conventions)
	centralMeridianLongitude = -zone*15.0
	if centralMeridianLongitude < 0.0:
		centralMeridianLongitude += 360.0
	localLongitude = -lon
	if localLongitude < 0.0:
		localLongitude += 360.0
	
	# Compute hour at mid of averaging time
	t1 = averagingPeriod / 3600.0
	t = timenow + 0.5*t1
	
	# Calculate seasonal correction for solar time
	b  = 2.*math.pi*(doy-81)/364.0
	Sc = 0.1645*math.sin(2.0*b) - 0.1255*math.cos(b) - 0.025*math.sin(b)
	
	# Solar time angle at midpoint of averaging time
	omega = (math.pi/12.0) * ((t + 0.06667*(centralMeridianLongitude - localLongitude) + Sc) - 12.0)
	
	# Solar time angle at beginning and end of averaging period
	omega1 = omega - math.pi*t1/24.0
	omega2 = omega + math.pi*t1/24.0

	# Adjust angular end points to exclude nighttime hours
	omegaS = math.acos(-math.tan(math.radians(lat))*math.tan(math.radians(solarDeclination)))		# Sunset angle
	if omega1 < -omegaS:
		omega1 = -omegaS
	if omega2 < -omegaS:
		omega2 = -omegaS
	if omega1 > omegaS:
		omega1 = omegaS
	if omega2 > omegaS:
		omega2 = omegaS
	if omega1 > omega2:
		omega1 = omega2
	
	# Compute extraterrestrial radiation
	ra = 
		12/math.pi * SOLAR_CONSTANT * dr * (
			(omega2-omega1)*math.sin(math.radians(lat))*math.sin(math.radians(solarDeclination)) +
			math.cos(math.radians(lat))*math.cos(math.radians(solarDeclination))*(math.sin(omega2) - math.sin(omega1))
		)
	
	return ra
