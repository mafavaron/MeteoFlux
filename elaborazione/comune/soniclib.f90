! SonicLib - Open source library for processing ultrasonic anemometer data
!
! Copyright 2012 by the SonicLib group (Università Statale di Milano - Dipartimento di Fisica)
!                       All rights reserved

! This is open-source software, distributed under license %%%

MODULE SonicLib

	IMPLICIT NONE
	
	PRIVATE
	
	! Public interface
	PUBLIC	:: GetRange
	PUBLIC	:: GetTimeSubset
	PUBLIC	:: RemoveLinearTrend
	PUBLIC	:: CheckTimeRegularity
	PUBLIC	:: OPERATOR(.VALID.)
	PUBLIC	:: Average
	PUBLIC	:: Covariance
	PUBLIC	:: RotationMatrix
	PUBLIC	:: BasicAnemology
	PUBLIC	:: WindDirClassify
	PUBLIC	:: WindStatistics
	PUBLIC	:: WindStatistics2D
	PUBLIC	:: BasicTurbulence
	
	! Interfaces
	
	INTERFACE OPERATOR(.VALID.)
		MODULE PROCEDURE IsValidReal, IsValidInteger
	END INTERFACE OPERATOR(.VALID.)

CONTAINS
	
	FUNCTION GetRange(rvData, lvDesiredSubset, rMinValue, rMaxValue) RESULT(iRetCode)
	
		! Routine arguments
		REAL, DIMENSION(:), INTENT(IN)		:: rvData
		LOGICAL, DIMENSION(:), INTENT(IN)	:: lvDesiredSubset
		REAL, INTENT(OUT)					:: rMinValue
		REAL, INTENT(OUT)					:: rMaxValue
		INTEGER								:: iRetCode
		
		! Locals
		INTEGER	:: iNumData
		
		! Assume success (will falsify on failure)
		iRetCode = 0
		
		! Check data size
		IF(COUNT(lvDesiredSubset) <= 0) THEN
			iRetCode = 1
			RETURN
		END IF
		
		! Compute extrema in data
		iNumData  = COUNT(lvDesiredSubset)
		IF(iNumData <= 0) THEN
			rMinValue = -9999.9
			rMaxValue = -9999.9
			iRetCode  = 2
			RETURN
		END IF
		rMinValue = MINVAL(rvData, MASK=lvDesiredSubset)
		rMaxValue = MAXVAL(rvData, MASK=lvDesiredSubset)
		
	END FUNCTION GetRange
	
	
	SUBROUTINE GetTimeSubset( &
		ivTimeStamp, &
		iAveraging, &
		iAvgBlock, &
		lvDesiredSubset, &
		iRetCode &
	)
	
		! Routine arguments
		INTEGER, DIMENSION(:), INTENT(IN)	:: ivTimeStamp
		INTEGER, INTENT(IN)					:: iAveraging
		INTEGER, INTENT(IN)					:: iAvgBlock
		LOGICAL, DIMENSION(:), INTENT(OUT)	:: lvDesiredSubset
		INTEGER								:: iRetCode
		
		! Locals
		INTEGER	:: iMaxBlocks
		INTEGER	:: iBeginBlock
		INTEGER	:: iEndBlock
		
		! Assume success (will falsify on failure)
		iRetCode = 0
		
		! Check block number to be compatible with averaging time
		iMaxBlocks = 3600/iAveraging
		IF(iAvgBlock < 1 .OR. iAvgBlock > iMaxBlocks) THEN
			iRetCode = 1
			RETURN
		END IF
		
		! Locate begin and end of desired block, according to averaging time
		iBeginBlock = iAveraging*(iAvgBlock-1)
		iEndBlock   = iBeginBlock + iAveraging
		
		! The desired set of data is characterized by time stamps >= than block begin,
		! and < than end of block.
		lvDesiredSubset = (ivTimeStamp >= iBeginBlock .AND. ivTimeStamp < iEndBlock)
	
	END SUBROUTINE GetTimeSubset
	
	
	! To be invoked only after CheckTimeRegularity, and provided time regularity
	! index has been found at least equal to 3.
	!
	! Trend removal is by far the most delicate step in the whole eddy covariance
	! chain. The implementation reflect this fact in containing some spots (like
	! normalization of time stamp) which look apparently useless, but whose existence
	! allows a real-world CPU treating numerical values sensibly-
	SUBROUTINE RemoveLinearTrend( &
		ivTimeStamp, &
		rvU, rvV, rvW, rvT, &
		iFrequency, &
		lvDesiredSubset, &
		rvTrendlessU, rvTrendlessV, rvTrendlessW, rvTrendlessT, &
		iRetCode &
	)
	
		! Routine arguments
		INTEGER, DIMENSION(:), INTENT(IN)	:: ivTimeStamp
		REAL, DIMENSION(:), INTENT(IN)		:: rvU
		REAL, DIMENSION(:), INTENT(IN)		:: rvV
		REAL, DIMENSION(:), INTENT(IN)		:: rvW
		REAL, DIMENSION(:), INTENT(IN)		:: rvT
		INTEGER, INTENT(IN)					:: iFrequency
		LOGICAL, DIMENSION(:), INTENT(IN)	:: lvDesiredSubset
		REAL, DIMENSION(:), INTENT(OUT)		:: rvTrendlessU
		REAL, DIMENSION(:), INTENT(OUT)		:: rvTrendlessV
		REAL, DIMENSION(:), INTENT(OUT)		:: rvTrendlessW
		REAL, DIMENSION(:), INTENT(OUT)		:: rvTrendlessT
		INTEGER, INTENT(OUT)				:: iRetCode
		
		! Locals
		INTEGER								:: iRegularityCode
		INTEGER								:: iErrCode
		REAL, DIMENSION(:), ALLOCATABLE		:: rvTimeStamp
		REAL, DIMENSION(:), ALLOCATABLE		:: rvTimeStampNormalized
		INTEGER								:: i
		INTEGER								:: iNumValid
		REAL								:: rSumX
		REAL								:: rSumX2
		REAL								:: rSumU
		REAL								:: rSumV
		REAL								:: rSumW
		REAL								:: rSumT
		REAL								:: rSumXU
		REAL								:: rSumXV
		REAL								:: rSumXW
		REAL								:: rSumXT
		REAL								:: rAlphaU
		REAL								:: rAlphaV
		REAL								:: rAlphaW
		REAL								:: rAlphaT
		REAL								:: rBetaU
		REAL								:: rBetaV
		REAL								:: rBetaW
		REAL								:: rBetaT
		
		! Assume success (will falsify on failure)
		iRetCode = 0
		
		! Check data chunk to be non-empty
		iNumValid = COUNT(lvDesiredSubset)
		IF(iNumValid <= 0) THEN
			iRetCode = 1
			RETURN
		END IF
		
		! Reserve workspace
		ALLOCATE(rvTimeStamp(SIZE(ivTimeStamp)),rvTimeStampNormalized(SIZE(ivTimeStamp)))
		
		! Attribute fictive time stamp based on frequency and index position
		rvTimeStamp = FLOAT([(i,i=1,SIZE(rvTimeStamp))]) / iFrequency
		rvTimeStampNormalized = rvTimeStamp/3600.
		
		! Estimate least square regression line over included data
		! -1- Compute time stamp specific summations
		rSumX  = SUM(rvTimeStampNormalized, MASK=lvDesiredSubset)
		rSumX2 = SUM(rvTimeStampNormalized**2, MASK=lvDesiredSubset)
		! -1- U-specific part
		rSumU  = SUM(rvU, MASK=lvDesiredSubset)
		rSumXU = SUM(rvTimeStampNormalized*rvU, MASK=lvDesiredSubset)
		rBetaU  = (rSumXU-rSumX*rSumU/iNumValid)/(rSumX2-rSumX**2/iNumValid)
		rAlphaU = rSumU/iNumValid - rBetaU*rSumX/iNumValid
		! -1- U-specific part
		rSumV  = SUM(rvV, MASK=lvDesiredSubset)
		rSumXV = SUM(rvTimeStampNormalized*rvV, MASK=lvDesiredSubset)
		rBetaV  = (rSumXV-rSumX*rSumV/iNumValid)/(rSumX2-rSumX**2/iNumValid)
		rAlphaV = rSumV/iNumValid - rBetaV*rSumX/iNumValid
		! -1- U-specific part
		rSumW  = SUM(rvW, MASK=lvDesiredSubset)
		rSumXW = SUM(rvTimeStampNormalized*rvW, MASK=lvDesiredSubset)
		rBetaW  = (rSumXW-rSumX*rSumW/iNumValid)/(rSumX2-rSumX**2/iNumValid)
		rAlphaW = rSumW/iNumValid - rBetaW*rSumX/iNumValid
		! -1- U-specific part
		rSumT  = SUM(rvT, MASK=lvDesiredSubset)
		rSumXT = SUM(rvTimeStampNormalized*rvT, MASK=lvDesiredSubset)
		rBetaT  = (rSumXT-rSumX*rSumT/iNumValid)/(rSumX2-rSumX**2/iNumValid)
		rAlphaT = rSumT/iNumValid - rBetaT*rSumX/iNumValid
		
		! Remove the "trend" estimated by regression line in average-preserving manner
		WHERE(lvDesiredSubset)
			rvTrendlessU = rvU - (rAlphaU + rBetaU*rvTimeStampNormalized)
			rvTrendlessU = rvTrendlessU - SUM(rvTrendlessU, MASK=lvDesiredSubset)/iNumValid + rSumU/iNumValid
			rvTrendlessV = rvV - (rAlphaV + rBetaV*rvTimeStampNormalized)
			rvTrendlessV = rvTrendlessV - SUM(rvTrendlessV, MASK=lvDesiredSubset)/iNumValid + rSumV/iNumValid
			rvTrendlessW = rvW - (rAlphaW + rBetaW*rvTimeStampNormalized)
			rvTrendlessW = rvTrendlessW - SUM(rvTrendlessW, MASK=lvDesiredSubset)/iNumValid + rSumW/iNumValid
			rvTrendlessT = rvT - (rAlphaT + rBetaT*rvTimeStampNormalized)
			rvTrendlessT = rvTrendlessT - SUM(rvTrendlessT, MASK=lvDesiredSubset)/iNumValid + rSumT/iNumValid
		ENDWHERE
		
		DEALLOCATE(rvTimeStamp)

	END SUBROUTINE RemovelinearTrend
	
	
	SUBROUTINE CheckTimeRegularity(ivTimeStamp, lvDesiredSubset, iFrequency, iRegularityCode, iRetCode)
	
		! Routine arguments
		INTEGER, DIMENSION(:), INTENT(IN)		:: ivTimeStamp
		LOGICAL, DIMENSION(:), INTENT(IN)		:: lvDesiredSubset
		INTEGER, INTENT(OUT)					:: iFrequency
		INTEGER, INTENT(OUT)					:: iRegularityCode
		INTEGER, INTENT(OUT)					:: iRetCode
		
		! Locals
		INTEGER, DIMENSION(0:3599)			:: ivNumTimeStamps
		INTEGER								:: iMaxNumStamps
		INTEGER								:: i
		INTEGER, DIMENSION(:), ALLOCATABLE	:: ivFrequency
		INTEGER, DIMENSION(1)				:: ivPos
		INTEGER								:: iActualData
		INTEGER								:: iExpectedData
		
		! Internal constants
		INTEGER, PARAMETER	:: COND_SORTED_DATA = 1
		INTEGER, PARAMETER	:: COND_NO_GAPS     = 2
	
		! Assume success (will falsify on failure)
		iRetCode = 0
		
		! Set initial state of 'iRegularityCode'
		iRegularityCode = 0
		
		! Get the number of time stamps (repeated, because only integer part is retained)
		ivNumTimeStamps = 0
		DO i = 1, SIZE(ivTimeStamp)
			IF(lvDesiredSubset(i) .AND. ivTimeStamp(i) >= 0 .AND. ivTimeStamp(i) <= 3599) THEN
				ivNumTimeStamps(ivTimeStamp(i)) = ivNumTimeStamps(ivTimeStamp(i)) + 1
			END IF
		END DO
		
		! Which is the most frequent number of time stamps? If it exists, it estimates
		! sampling frequency.
		iMaxNumStamps = MAXVAL(ivNumTimeStamps)
		IF(iMaxNumStamps <= 0) THEN
			iRegularityCode = 0
			iRetCode = 1
			RETURN
		END IF
		ALLOCATE(ivFrequency(iMaxNumStamps))
		ivFrequency = 0
		DO i = 0, 3599
			IF(ivNumTimeStamps(i) > 0) THEN
				ivFrequency(ivNumTimeStamps(i)) = ivFrequency(ivNumTimeStamps(i)) + 1
			END IF
		END DO
		ivPos = MAXLOC(ivFrequency)
		iFrequency = ivPos(1)
		iRegularityCode = iRegularityCode + COND_SORTED_DATA
		
		! Check no gaps are present in data record, with gaps defined as
		! expected lines not received; invalid data are not considered
		! "gaps"
		iActualData = SUM(ivNumTimeStamps)
		iExpectedData = iFrequency * &
						(MAXVAL(ivTimeStamp, MASK=ivTimeStamp >= 0 .AND. ivTimeStamp < 3600 .AND. lvDesiredSubset) - &
						 MINVAL(ivTimeStamp, MASK=ivTimeStamp >= 0 .AND. ivTimeStamp < 3600 .AND. lvDesiredSubset) + 1)
		IF(FLOAT(ABS(iActualData-iExpectedData)) / FLOAT(iExpectedData) <= 0.01) THEN
			iRegularityCode = iRegularityCode + COND_NO_GAPS
		END IF
		
		! Leave
		DEALLOCATE(ivFrequency)
	
	END SUBROUTINE CheckTimeRegularity
	
	
	SUBROUTINE Average(rvX, lvDesiredSubSet, rAvg)
	
		! Routine arguments
		REAL, DIMENSION(:), INTENT(IN)		:: rvX
		LOGICAL, DIMENSION(:), INTENT(IN)	:: lvDesiredSubset
		REAL, INTENT(OUT)					:: rAvg
		
		! Locals
		INTEGER	:: iNumData
		
		! Compute average, limiting attention to desired data
		iNumData = COUNT(lvDesiredSubset)
		IF(iNumData > 0) THEN
			rAvg = SUM(rvX, MASK=lvDesiredSubset) / iNumData
		ELSE
			rAvg = -9999.9
		END IF
		
	END SUBROUTINE Average
	
	
	SUBROUTINE Covariance(rvX, rvY, lvDesiredSubset, rAvgX, rAvgY, rCov)
	
		! Routine arguments
		REAL, DIMENSION(:), INTENT(IN)		:: rvX
		REAL, DIMENSION(:), INTENT(IN)		:: rvY
		LOGICAL, DIMENSION(:), INTENT(IN)	:: lvDesiredSubset
		REAL, INTENT(IN)					:: rAvgX
		REAL, INTENT(IN)					:: rAvgY
		REAL, INTENT(OUT)					:: rCov
		
		! Locals
		INTEGER	:: iNumData
		
		! Compute average, limiting attention to desired data
		iNumData = COUNT(lvDesiredSubset)
		IF(iNumData > 0) THEN
			rCov = SUM((rvX-rAvgX)*(rvY-rAvgY), MASK=lvDesiredSubset) / iNumData
		ELSE
			rCov = -9999.9
		END IF
		
	END SUBROUTINE Covariance
	
	
	FUNCTION RotationMatrix(iNumRot, rvAvgWind, rmCovWind, rTheta, rPhi, rPsi) RESULT(rmRot)
	
		! Routine arguments
		INTEGER, INTENT(IN)					:: iNumRot		! Nr. rotations (0, 1, 2 or 3)
		REAL, DIMENSION(3), INTENT(IN)		:: rvAvgWind
		REAL, DIMENSION(3,3), INTENT(IN)	:: rmCovWind
		REAL, INTENT(OUT)					:: rTheta
		REAL, INTENT(OUT)					:: rPhi
		REAL, INTENT(OUT)					:: rPsi
		REAL, DIMENSION(3,3)				:: rmRot
		
		! Locals
		REAL, DIMENSION(3,3)	:: rmR
		REAL, DIMENSION(3,3)	:: rmS
		REAL, DIMENSION(3,3)	:: rmT
		REAL, DIMENSION(3,3)	:: rmCovRot2
		REAL, DIMENSION(3,3), PARAMETER	:: I = RESHAPE( (/1.,0.,0.,0.,1.,0.,0.,0.,1./), (/3,3/))
		
		REAL, PARAMETER			:: PI = 3.1415927
		
		! Check something is to be made
		IF(iNumRot <= 0) THEN
			! No rotations: the "rotation" matrix degenerates to I
			rmRot = I
			RETURN
		END IF
		
		! Compute first rotation matrix
		rTheta = ATAN2(rvAvgWind(2),rvAvgWind(1))
		rmR = 0.
		rmR(1,1) = COS(rTheta)
		rmR(2,2) = rmR(1,1)
		rmR(3,3) = 1.
		rmR(1,2) = SIN(rTheta)
		rmR(2,1) = -rmR(1,2)
		
		! Compute second rotation matrix, if requested
		IF(iNumRot >= 2) THEN
			rPhi = ATAN2(rvAvgWind(3),SQRT(rvAvgWind(1)**2 + rvAvgWind(2)**2))
			rmS = 0.
			rmS(1,1) = COS(rPhi)
			rmS(3,3) = rmS(1,1)
			rmS(2,2) = 1.
			rmS(1,3) = SIN(rPhi)
			rmS(3,1) = -rmS(1,3)
			rmRot = MATMUL(rmS, rmR)
		ELSE
			rPhi = 0.
			rmRot = rmR
		END IF
		
		! Compute third rotation matrix, if requested
		IF(iNumRot >= 3) THEN
			rmCovRot2 = MATMUL(MATMUL(rmRot,rmCovWind),TRANSPOSE(rmRot))
			IF(ABS(rmCovRot2(2,3)) >= 1.e-6 .OR. ABS(rmCovRot2(2,2) - rmCovRot2(3,3)) >= 1.e-6) THEN
				rPsi = 0.5*ATAN2(2.*rmCovRot2(2,3),rmCovRot2(2,2) - rmCovRot2(3,3))
				rmT = 0.
				rmT(2,2) = COS(rPsi)
				rmT(3,3) = rmT(2,2)
				rmT(1,1) = 1.
				rmT(2,3) = SIN(rPsi)
				rmT(3,2) = -rmT(2,3)
				rmRot = MATMUL(rmT,rmRot)
			ELSE
				rPsi = 0.
			END IF
		END IF
		
	END FUNCTION RotationMatrix
	
	
	FUNCTION BasicAnemology(rvWindAvg, rVel, rDir, r3dVel) RESULT(iRetCode)
	
		! Routine arguments
		REAL, DIMENSION(3), INTENT(IN)	:: rvWindAvg
		REAL, INTENT(OUT)				:: rVel
		REAL, INTENT(OUT)				:: rDir
		REAL, INTENT(OUT)				:: r3dVel
		INTEGER							:: iRetCode
		
		! Locals
		REAL, PARAMETER	:: PI = 3.1415927
		
		! Assume success (will falsify on failure)
		iRetCode = 0
		
		! Compute horizontal and full-vector wind speeds
		rVel = SQRT(SUM(rvWindAvg(1:2)**2))
		r3dVel = SQRT(SUM(rvWindAvg**2))
		
		! Compute horizontal wind direction (provenance convention: see sign of wind components!)
		rDir = 180./PI * ATAN2(-rvWindAvg(1), -rvWindAvg(2))
		IF(rDir <    0.) rDir = rDir + 360.
		IF(rDir >= 360.) rDir = rDir - 360.
		
	END FUNCTION BasicAnemology
	

	FUNCTION WindDirClassify( &
		rvU, rvV, &
		lvDesiredSubset, &
		ivDirClass, &
		rDominantDir &
	) RESULT(iRetCode)
		
		! Routine arguments
		REAL, DIMENSION(:), INTENT(IN)		:: rvU
		REAL, DIMENSION(:), INTENT(IN)		:: rvV
		LOGICAL, DIMENSION(:), INTENT(IN)	:: lvDesiredSubset
		INTEGER, DIMENSION(16), INTENT(OUT)	:: ivDirClass
		REAL, INTENT(OUT)					:: rDominantDir
		INTEGER								:: iRetCode
		
		! Locals
		INTEGER					:: iIncluded
		INTEGER					:: i, j
		REAL					:: rU
		REAL					:: rV
		REAL					:: rVel
		REAL					:: rDir
		INTEGER					:: iDirIndex
		INTEGER, DIMENSION(1)	:: ivPos
		
		! Internal constants
		REAL, PARAMETER	:: CLASS_WIDTH = 360./16.
		REAL, PARAMETER	:: HALF_CLASS  = CLASS_WIDTH / 2.
		
		! Assume success (will falsify on failure)
		iRetCode = 0
		
		! Compute direction classes
		ivDirClass = 0
		DO i = 1, SIZE(rvU)
			IF(lvDesiredSubset(i)) THEN
			
				rU = rvU(i)
				rV = rvV(i)
				rVel = SQRT(rU**2 + rV**2)
				IF(rVel > 1.e-6) THEN
				
					! Compute direction
					rDir = 180./3.1415927 * ATAN2(-rU, -rV)
					
					! Prepare direction for classification 
					rDir = rDir + HALF_CLASS	! So, class 1 goes from -12.5 to +12.5°
					IF(rDir <    0.) rDir = rDir + 360.
					IF(rDir >= 360.) rDir = rDir - 360.
					
					! Compute classification index and use it to update its corresponding class count
					iDirIndex = FLOOR(rDir/CLASS_WIDTH) + 1
					IF(iDirIndex >= 1 .AND. iDirIndex <= 16) THEN	! Just defensive programming: should "always" be!
						ivDirClass(iDirIndex) = ivDirClass(iDirIndex) + 1
					END IF
					
				END IF
				
			END IF
		END DO
		
		! Compute dominant direction
		ivPos = MAXLOC(ivDirClass)
		rDominantDir = CLASS_WIDTH*(ivPos(1)-1)

	END FUNCTION WindDirClassify
	
	
	FUNCTION WindStatistics( &
		rvU, rvV, rvW, &	! Wind components in *non rotated frame* (m/s)
		lvDesiredSubset, &	! Logical vector whose .TRUE. components delimit data to be used
		rVectorVel, &		! Horizontal vector ("usual") wind speed (m/s)
		rVectorDir, &		! Horizontal vector wind direction (° from N)
		r3DVel, &			! Full vector wind speed (m/s)
		rScalarVel, &		! "Scalar" velocity, that is, mean of instantaneoud velocities (m/s)
		rScalarVelStd, &	! Standard deviation of scalar velocity (m/s)
		rUnitVectorDir, &	! Mean direction with all data having been weighted 1. (° from N)
		rEstSigmaDir, &		! Yamartino's estimate of direction standard deviation (°)
		rPhi, &				! Mean angle to horizontal (°)
		rSigmaPhi, &		! Standard deviation of angle to horizontal (°)
		rUnitVel, &			! Mean "velocity" obtained  summing unit vectors from instantaneous directions (m/s)
		rDirCircVar, &		! Circular variance (not the same as the square of circular standard deviation!)
		rDirCircStd &		! Circular standard deviation (not the same as the square root of circular variance!)
	) RESULT(iRetCode)
		
		! Routine arguments
		REAL, DIMENSION(:), INTENT(IN)		:: rvU
		REAL, DIMENSION(:), INTENT(IN)		:: rvV
		REAL, DIMENSION(:), INTENT(IN)		:: rvW
		LOGICAL, DIMENSION(:), INTENT(IN)	:: lvDesiredSubset
		REAL, INTENT(OUT)					:: rVectorVel
		REAL, INTENT(OUT)					:: rVectorDir
		REAL, INTENT(OUT)					:: r3DVel
		REAL, INTENT(OUT)					:: rScalarVel
		REAL, INTENT(OUT)					:: rScalarVelStd
		REAL, INTENT(OUT)					:: rUnitVectorDir
		REAL, INTENT(OUT)					:: rEstSigmaDir
		REAL, INTENT(OUT)					:: rPhi
		REAL, INTENT(OUT)					:: rSigmaPhi
		REAL, INTENT(OUT)					:: rUnitVel
		REAL, INTENT(OUT)					:: rDirCircVar
		REAL, INTENT(OUT)					:: rDirCircStd
		INTEGER								:: iRetCode
		
		! Locals
		REAL, DIMENSION(SIZE(rvU))	:: rvVel
		REAL, DIMENSION(SIZE(rvU))	:: rvUnitU
		REAL, DIMENSION(SIZE(rvU))	:: rvUnitV
		REAL, DIMENSION(SIZE(rvU))	:: rvPhi
		INTEGER						:: iNumData
		REAL						:: rUnitU
		REAL						:: rUnitV
		REAL						:: rMeanU
		REAL						:: rMeanV
		REAL						:: rMeanW
		REAL						:: rEpsilon
		INTEGER						:: i
		
		! Internal constants
		REAL, PARAMETER	:: PI = 3.1415926535
		REAL, PARAMETER	:: TO_DEGREES = 180./PI
		
		! Assume success (will falsify on failure)
		iRetCode = 0
		
		! Check something is to be made
		IF(.NOT.ANY(lvDesiredSubset)) THEN
			iRetCode = 1
			RETURN
		END IF
		! Post-condition: At least one data requested: all steps following make sense.
		
		! Compute statistics
		iNumData = COUNT(lvDesiredSubset)
		
		! Compute vector velocities
		rMeanU = SUM(rvU, MASK=lvDesiredSubset)/iNumData
		rMeanV = SUM(rvV, MASK=lvDesiredSubset)/iNumData
		rMeanW = SUM(rvW, MASK=lvDesiredSubset)/iNumData
		rVectorVel = SQRT(rMeanU**2 + rMeanV**2)
		r3DVel = SQRT(rMeanU**2 + rMeanV**2 + rMeanW**2)
		
		! Vector wind direction
		rVectorDir = TO_DEGREES * ATAN2(-rMeanU, -rMeanV)
		IF(rVectorDir < 0.) rVectorDir = rVectorDir + 360.
		
		! Build auxiliary vectors
		DO i = 1, SIZE(lvDesiredSubset)
			IF(lvDesiredSubset(i)) THEN
				rvVel(i)   = SQRT(rvU(i)**2 + rvV(i)**2)
				rvUnitU(i) = rvU(i) / rvVel(i)
				rvUnitV(i) = rvV(i) / rvVel(i)
				rvPhi(i)   = TO_DEGREES*ATAN2(rvW(i), rvVel(i))
			END IF
		END DO
		
		! Compute scalar velocity and its standard deviation
		rScalarVel = SUM(rvVel, MASK=lvDesiredSubset) / iNumData
		rScalarVelStd = SQRT(SUM(rvVel**2, MASK=lvDesiredSubset)/iNumData - rScalarVel**2)
		
		! Build unit vactors and related statistics
		rUnitU  = SUM(rvUnitU, MASK=lvDesiredSubset) / iNumData
		rUnitV  = SUM(rvUnitV, MASK=lvDesiredSubset) / iNumData
		rEpsilon       = SQRT(MAX(1.-rUnitU**2-rUnitV**2, 0.))
		rEstSigmaDir   = TO_DEGREES * ASIN(rEpsilon) * (1.0 + 0.1547*rEpsilon**3)
		rUnitVectorDir = TO_DEGREES * ATAN2(-rUnitU, -rUnitV)
		IF(rUnitVectorDir <    0.) rUnitVectorDir = rUnitVectorDir + 360.
		IF(rUnitVectorDir >= 360.) rUnitVectorDir = rUnitVectorDir - 360.
		rUnitVel       = SQRT(rUnitU**2 + rUnitV**2)
		IF(ABS(rUnitVel) > 0.0001) THEN
			rDirCircVar    = 1. - rUnitVel
			rDirCircStd    = SQRT(-LOG(rUnitVel))
		ELSE
			rDirCircVar    = -9999.9
			rDirCircStd    = -9999.9
		END IF
		
		! Angle to horizontal plane
		rPhi = SUM(rvPhi, MASK=lvDesiredSubset) / iNumData
		rSigmaPhi = SQRT(SUM(rvPhi**2, MASK=lvDesiredSubset)/iNumData - rPhi**2)
		
	END FUNCTION WindStatistics
	
	
	FUNCTION WindStatistics2D( &
		rvU, rvV, &			! Wind components (m/s)
		lvDesiredSubset, &	! Logical vector whose .TRUE. components delimit data to be used
		rVectorVel, &		! Horizontal vector ("usual") wind speed (m/s)
		rVectorDir, &		! Horizontal vector wind direction (° from N)
		rScalarVel, &		! "Scalar" velocity, that is, mean of instantaneoud velocities (m/s)
		rScalarVelStd, &	! Standard deviation of scalar velocity (m/s)
		rUnitVectorDir, &	! Mean direction with all data having been weighted 1. (° from N)
		rEstSigmaDir, &		! Yamartino's estimate of direction standard deviation (°)
		rUnitVel, &			! Mean "velocity" obtained  summing unit vectors from instantaneous directions (m/s)
		rDirCircVar, &		! Circular variance (not the same as the square of circular standard deviation!)
		rDirCircStd &		! Circular standard deviation (not the same as the square root of circular variance!)
	) RESULT(iRetCode)
		
		! Routine arguments
		REAL, DIMENSION(:), INTENT(IN)		:: rvU
		REAL, DIMENSION(:), INTENT(IN)		:: rvV
		LOGICAL, DIMENSION(:), INTENT(IN)	:: lvDesiredSubset
		REAL, INTENT(OUT)					:: rVectorVel
		REAL, INTENT(OUT)					:: rVectorDir
		REAL, INTENT(OUT)					:: rScalarVel
		REAL, INTENT(OUT)					:: rScalarVelStd
		REAL, INTENT(OUT)					:: rUnitVectorDir
		REAL, INTENT(OUT)					:: rEstSigmaDir
		REAL, INTENT(OUT)					:: rUnitVel
		REAL, INTENT(OUT)					:: rDirCircVar
		REAL, INTENT(OUT)					:: rDirCircStd
		INTEGER								:: iRetCode
		
		! Locals
		REAL, DIMENSION(SIZE(rvU))	:: rvVel
		REAL, DIMENSION(SIZE(rvU))	:: rvUnitU
		REAL, DIMENSION(SIZE(rvU))	:: rvUnitV
		REAL, DIMENSION(SIZE(rvU))	:: rvPhi
		INTEGER						:: iNumData
		REAL						:: rUnitU
		REAL						:: rUnitV
		REAL						:: rMeanU
		REAL						:: rMeanV
		REAL						:: rEpsilon
		INTEGER						:: i
		
		! Internal constants
		REAL, PARAMETER	:: PI = 3.1415926535
		REAL, PARAMETER	:: TO_DEGREES = 180./PI
		
		! Assume success (will falsify on failure)
		iRetCode = 0
		
		! Check something is to be made
		IF(.NOT.ANY(lvDesiredSubset)) THEN
			iRetCode = 1
			RETURN
		END IF
		! Post-condition: At least one data requested: all steps following make sense.
		
		! Compute statistics
		iNumData = COUNT(lvDesiredSubset)
		
		! Compute vector velocities
		rMeanU = SUM(rvU, MASK=lvDesiredSubset)/iNumData
		rMeanV = SUM(rvV, MASK=lvDesiredSubset)/iNumData
		rVectorVel = SQRT(rMeanU**2 + rMeanV**2)
		
		! Vector wind direction
		rVectorDir = TO_DEGREES * ATAN2(-rMeanU, -rMeanV)
		IF(rVectorDir < 0.) rVectorDir = rVectorDir + 360.
		
		! Build auxiliary vectors
		DO i = 1, SIZE(lvDesiredSubset)
			IF(lvDesiredSubset(i)) THEN
				rvVel(i)   = SQRT(rvU(i)**2 + rvV(i)**2)
				if(rvVel(i) > 0.) then
					rvUnitU(i) = rvU(i) / rvVel(i)
					rvUnitV(i) = rvV(i) / rvVel(i)
				else
					rvUnitU(i) = 0.0
					rvUnitV(i) = 0.0
				end if
			END IF
		END DO
		
		! Compute scalar velocity and its standard deviation
		rScalarVel = SUM(rvVel, MASK=lvDesiredSubset) / iNumData
		rScalarVelStd = SQRT(SUM(rvVel**2, MASK=lvDesiredSubset)/iNumData - rScalarVel**2)
		
		! Build unit vactors and related statistics
		rUnitU  = SUM(rvUnitU, MASK=lvDesiredSubset) / iNumData
		rUnitV  = SUM(rvUnitV, MASK=lvDesiredSubset) / iNumData
		rEpsilon       = SQRT(MAX(1.-rUnitU**2-rUnitV**2, 0.))
		rEstSigmaDir   = TO_DEGREES * ASIN(rEpsilon) * (1.0 + 0.1547*rEpsilon**3)
		rUnitVectorDir = TO_DEGREES * ATAN2(-rUnitU, -rUnitV)
		IF(rUnitVectorDir <    0.) rUnitVectorDir = rUnitVectorDir + 360.
		IF(rUnitVectorDir >= 360.) rUnitVectorDir = rUnitVectorDir - 360.
		rUnitVel       = SQRT(rUnitU**2 + rUnitV**2)
		IF(ABS(rUnitVel) > 0.0001) THEN
			rDirCircVar    = 1. - rUnitVel
			rDirCircStd    = SQRT(-LOG(rUnitVel))
		ELSE
			rDirCircVar    = -9999.9
			rDirCircStd    = -9999.9
		END IF
		
	END FUNCTION WindStatistics2D
	
	
	FUNCTION BasicTurbulence( &
		rZ, rZr, rTemperature, &
		rmRotCov, rvRotCovT, rVarT, &
		rUstar, rTstar, &
		rH0, rZl, rTKE, &
		rSigmaU, rSigmaV, rSigmaW, rSigmaT &
	) RESULT(iRetCode)
	
		! Routine arguments
		REAL, INTENT(IN)					:: rZ			! Station altitude above geoid, in m
		REAL, INTENT(IN)					:: rZr			! Anemometer height above ground, in m
		REAL, INTENT(IN)					:: rTemperature	! Mean temperature, in °C
		REAL, DIMENSION(3,3), INTENT(IN)	:: rmRotCov		! Wind covariances, in rotated frame
		REAL, DIMENSION(3), INTENT(IN)		:: rvRotCovT	! Wind-temperature covariances, in rotated frame
		REAL, INTENT(IN)					:: rVarT		! Variance of temperature (°C^2)
		REAL, INTENT(OUT)					:: rUstar		! Friction velocity
		REAL, INTENT(OUT)					:: rTstar		! Scale temperature
		REAL, INTENT(OUT)					:: rH0			! Turbulent sensible heat flux
		REAL, INTENT(OUT)					:: rZl			! Zr/L, where Zr is anemometer height and L the Obukhov length
		REAL, INTENT(OUT)					:: rTKE			! Turbulent kinetic energy
		REAL, INTENT(OUT)					:: rSigmaU		! Standard deviation of component U
		REAL, INTENT(OUT)					:: rSigmaV		! Standard deviation of component V
		REAL, INTENT(OUT)					:: rSigmaW		! Standard deviation of component W
		REAL, INTENT(OUT)					:: rSigmaT		! Standard deviation of component T
		INTEGER								:: iRetCode
		
		! Locals
		REAL, PARAMETER	:: K = 0.4	! von Kalman constant
		REAL, PARAMETER	:: g = 9.81
		REAL			:: rRhoCp
		REAL			:: rTemp
		REAL			:: rUU, rUV, rUW, rVV, rVW, rWW, rWT
		
		! Assume success (will falsify on failure)
		iRetCode = 0
		
		! Extract components from cov matrix (not really necessary, but makes
		! reading clearer to physically inclined people)
		rUU = rmRotCov(1,1)
		rVV = rmRotCov(2,2)
		rWW = rmRotCov(3,3)
		rUV = rmRotCov(1,2)
		rUW = rmRotCov(1,3)
		rVW = rmRotCov(2,3)
		rWT = rvRotCovT(3)
		
		! Check parameters
		IF(rUU < 0. .OR. rVV < 0. .OR. rWW < 0.) THEN
			iRetCode = 1
			RETURN
		END IF
		
		! Estimate Rho*Cp
		rTemp  = rTemperature + 273.15
		rRhoCp = RhoCp(rZ, rTemp)
		
		! Compute the quantities desired
		rTKE = 0.5*(rUU + rVV + rWW)
		rSigmaU = SQRT(rUU)
		rSigmaV = SQRT(rVV)
		rSigmaW = SQRT(rWW)
		rSigmaT = SQRT(rVarT)
		rUstar  = MAX((rUW**2 + rVW**2)**0.25, 0.001)
		rTstar  = -rWT / rUstar
		rH0     = rRhoCp * rWT
		rZl     = -K*rZr*g/rTemp * rWT / rUstar**3
		
	END FUNCTION BasicTurbulence

	! *************************************************
	! * Ancillary routines (all internal, non-public) *
	! *************************************************
		
	ELEMENTAL FUNCTION IsValidReal(rValue) RESULT(lIsValid)
	
		! Routine arguments
		REAL, INTENT(IN)	:: rValue
		LOGICAL				:: lIsValid
		
		! Locals
		! -none-
		
		! Get desired information
		lIsValid = rValue >= -9990.0
			
	END FUNCTION IsValidReal
	
		
	ELEMENTAL FUNCTION IsValidInteger(iValue) RESULT(lIsValid)
	
		! Routine arguments
		INTEGER, INTENT(IN)	:: iValue
		LOGICAL				:: lIsValid
		
		! Locals
		! -none-
		
		! Get desired information
		lIsValid = iValue >= -9990
			
	END FUNCTION IsValidInteger
	
	
	FUNCTION RhoCp(rHeight, rTemperature) RESULT(rRhoCp)
	
		! Routine arguments
		REAL, INTENT(IN)	:: rHeight			! Station altitude above geoid (m)
		REAL, INTENT(IN)	:: rTemperature		! Sonic temperature, already converted to K
		REAL				:: rRhoCp
		
		! Locals
		REAL	:: rNonNegativeHeight
		REAL	:: rPressure
		REAL	:: rTemp
		
		! Compute rho * Cp using hydrostatic approximation
		rNonNegativeHeight = MAX(0., rHeight)
		rPressure          = 1013.0 * EXP(-0.0342/rTemperature*rNonNegativeHeight)
		rRhoCp             = 350.125*rPressure/rTemperature
	
	END FUNCTION RhoCp
	
END MODULE SonicLib

