PROGRAM eddy_cov

	USE SonicLib
	USE Calendar

	IMPLICIT NONE
	
	! Locals
	CHARACTER(LEN=256)		:: sDataPath
	CHARACTER(LEN=256)		:: sToFile
	CHARACTER(LEN=256)		:: sInputFile
	CHARACTER(LEN=256)		:: sProcessedFile
	CHARACTER(LEN=512)		:: sCommand
	CHARACTER(LEN=20)		:: sDateTime
	CHARACTER(LEN=20)		:: sAvgTime
	CHARACTER(LEN=20)		:: sFuse
	INTEGER					:: iFuse
	INTEGER					:: iRetCode
	INTEGER, DIMENSION(10)	:: ivValues
	INTEGER					:: iAveragingTime
	INTEGER					:: iYear, iMonth, iDay, iHour, iMinute, iSecond
	INTEGER					:: iYear1, iMonth1, iDay1, iHour1, iMinute1, iSecond1
	INTEGER					:: iBlockYear, iBlockMonth, iBlockDay, iBlockHour, iBlockMinute, iBlockSecond
	CHARACTER(LEN=20)		:: sBlockTime
	INTEGER					:: iBlockTime
	LOGICAL					:: lIsFile
	INTEGER					:: i
	INTEGER, DIMENSION(:), ALLOCATABLE	:: ivTime
	REAL, DIMENSION(:), ALLOCATABLE		:: rvU	! W->E wind component (m/s, flow convention)
	REAL, DIMENSION(:), ALLOCATABLE		:: rvV	! N->S wind component (m/s, flow convention)
	REAL, DIMENSION(:), ALLOCATABLE		:: rvT	! Sonic temperature (°C)
	INTEGER, DIMENSION(:), ALLOCATABLE	:: ivQ	! Data quality (%)
	LOGICAL, DIMENSION(:), ALLOCATABLE	:: lvDesiredSubset
	LOGICAL, DIMENSION(:), ALLOCATABLE	:: lvValid
	REAL								:: rMinValue
	REAL								:: rMaxValue
	INTEGER								:: iNumInvalid
	INTEGER								:: iFrequency
	INTEGER								:: iMaxBlock
	INTEGER								:: iBlockLimit
	INTEGER								:: iBlock
	INTEGER								:: iCurTime
	INTEGER								:: iHourBegin
	INTEGER								:: iRegularityCode
	INTEGER								:: iTotData
	INTEGER								:: iValidData
	INTEGER								:: iMaxTimeStamp
	INTEGER								:: iMaxYear, iMaxMonth, iMaxDay, iMaxHour, iMaxMinute, iMaxSecond
	
	! Data set
	INTEGER, DIMENSION(:), ALLOCATABLE		:: ivTimeStamp
	INTEGER, DIMENSION(:), ALLOCATABLE		:: ivFrequency
	INTEGER, DIMENSION(:), ALLOCATABLE		:: ivRegularityCode
	INTEGER, DIMENSION(:), ALLOCATABLE		:: ivTotData
	INTEGER, DIMENSION(:), ALLOCATABLE		:: ivUsedData
	REAL, DIMENSION(:,:), ALLOCATABLE		:: raMin		! Wind components minima
	REAL, DIMENSION(:,:), ALLOCATABLE		:: raMax		! Wind components maxima
	REAL, DIMENSION(:), ALLOCATABLE			:: rvMinT		! Temperature, minima
	REAL, DIMENSION(:), ALLOCATABLE			:: rvMaxT		! Temperature, maxima
	REAL, DIMENSION(:,:), ALLOCATABLE		:: raAvg		! Wind components averages, non rotated
	REAL, DIMENSION(:), ALLOCATABLE			:: rvAvgT		! Temperature average
	REAL, DIMENSION(:), ALLOCATABLE			:: rvVarT		! Temperature standard deviation
	REAL, DIMENSION(:,:,:), ALLOCATABLE		:: raCov		! Wind components covariances
	REAL, DIMENSION(:,:), ALLOCATABLE		:: raCovT		! Wind-Temperature covariances
	REAL, DIMENSION(:), ALLOCATABLE			:: rvVectorVel
	REAL, DIMENSION(:), ALLOCATABLE			:: rvVectorDir
	REAL, DIMENSION(:), ALLOCATABLE			:: rvScalarVel
	REAL, DIMENSION(:), ALLOCATABLE			:: rvScalarVelStd
	REAL, DIMENSION(:), ALLOCATABLE			:: rvUnitVectorDir
	REAL, DIMENSION(:), ALLOCATABLE			:: rvEstSigmaDir
	REAL, DIMENSION(:), ALLOCATABLE			:: rvUnitVel
	REAL, DIMENSION(:), ALLOCATABLE			:: rvDirCircVar
	REAL, DIMENSION(:), ALLOCATABLE			:: rvDirCircStd
	INTEGER, DIMENSION(:,:), ALLOCATABLE	:: iaDirClass
	REAL, DIMENSION(:), ALLOCATABLE			:: rvDominantDir
	REAL, DIMENSION(:), ALLOCATABLE			:: rvSigmaU
	REAL, DIMENSION(:), ALLOCATABLE			:: rvSigmaV
	REAL, DIMENSION(:), ALLOCATABLE			:: rvSigmaT
	
	! Constants
	INTEGER, PARAMETER	:: STAT_SOUNDNESS_PERCENTAGE = 75
	
	! Get input parameters
	IF(COMMAND_ARGUMENT_COUNT() /= 4) THEN
		PRINT *,'proc2d - Program implementing simple processing for uSonic-2 anemometers'
		PRINT *
		PRINT *,'Usage:'
		PRINT *
		PRINT *,'  ./proc2d <DataPath> <DateTime> <AvgTime> <Fuse>'
		PRINT *
		PRINT *,'Averaging time, <AvgTime>, in seconds'
		PRINT *
		PRINT *,'Copyright 2017 by Servizi Territorio srl'
		PRINT *,'                  All rights reserved'
		PRINT *
		PRINT *,'Program "proc2d" is based on SonicLib open source ultrasonic'
		PRINT *,'data processing library. SonicLib is copyright by Università'
		PRINT *,'Statale di Milano, under license LGPL 2.0'
		PRINT *
		STOP
	END IF
	CALL GET_COMMAND_ARGUMENT(1, sDataPath)
	CALL GET_COMMAND_ARGUMENT(2, sDateTime)
	CALL GET_COMMAND_ARGUMENT(3, sAvgTime)
	READ(sAvgTime, *, IOSTAT=iRetCode) iAveragingTime
	IF(iRetCode /= 0) THEN
		PRINT *,'proc2d:: error: Invalid averaging time'
		STOP
	END IF
	CALL GET_COMMAND_ARGUMENT(4, sFuse)
	READ(sFuse, *, IOSTAT=iRetCode) iFuse
	IF(iRetCode /= 0) THEN
		PRINT *,'proc2d:: error: Invalid fuse'
		STOP
	END IF
	
	! Get current date and time, for diagnostic purposes
	CALL DATE_AND_TIME(VALUES=ivValues)
	
	! Build input file name, expected to be in sDataPath (on ram disk)
	READ(sDateTime, "(i4,5(1x,i2))", IOSTAT=iRetCode) iYear, iMonth, iDay, iHour, iMinute, iSecond
	IF(iRetCode /= 0) THEN
		PRINT *,'proc2d:: error: Invalid start of acquisition block'
		STOP
	END IF
	WRITE(sInputFile, "(a, '/', i4.4, 2i2.2, '.', i2.2, 'S')") &
		TRIM(sDataPath), iYear, iMonth, iDay, iHour
	INQUIRE(FILE=sInputFile, EXIST=lIsFile)
	IF(.NOT.lIsFile) THEN
		PRINT *,'proc2d:: error: Input file, ',TRIM(sInputFile),', not found'
		STOP
	END IF
	
	! Compute number of blocks to process, and reserve block-related workspace
	CALL PackTime(iCurTime, iYear, iMonth, iDay, iHour, iMinute, iSecond)
	CALL PackTime(iHourBegin, iYear, iMonth, iDay, iHour, 0, 0)
	iMaxBlock = (iCurTime - iHourBegin) / iAveragingTime + 1
	ALLOCATE( &
		ivTimeStamp(iMaxBlock), ivFrequency(iMaxBlock), ivRegularityCode(iMaxBlock), &
		ivTotData(iMaxBlock), ivUsedData(iMaxBlock), &
		raMin(iMaxBlock,2), raMax(iMaxBlock,2), &
		rvMinT(iMaxBlock), rvMaxT(iMaxBlock), &
		raAvg(iMaxBlock,2), &
		rvAvgT(iMaxBlock), rvVarT(iMaxBlock), &
		raCov(iMaxBlock,2,2), &
		raCovT(iMaxBlock,2), &
		rvVectorVel(iMaxBlock), rvVectorDir(iMaxBlock), &
		rvScalarVel(iMaxBlock), rvScalarVelStd(iMaxBlock), &
		rvUnitVectorDir(iMaxBlock), rvEstSigmaDir(iMaxBlock), &
		rvUnitVel(iMaxBlock), rvDirCircVar(iMaxBlock), rvDirCircStd(iMaxBlock), &
		iaDirClass(iMaxBlock, 16), rvDominantDir(iMaxBlock), &
		rvSigmaU(iMaxBlock), rvSigmaV(iMaxBlock), rvSigmaT(iMaxBlock) &
	)
	
	! Get input file
	iRetCode = ReadInputFile2d(10, sInputFile, ivTime, rvU, rvV, rvT, ivQ)
	IF(iRetCode /= 0) THEN
		PRINT *,'eddy_cov:: error: Input file not read (empty or missing)'
		STOP
	END IF
	ALLOCATE( &
		lvDesiredSubset(SIZE(ivTime)), lvValid(SIZE(ivTime)) &
	)
	
	! Which data are valid?
	do i = 1, size(ivTime)
		lvValid(i) = &
			(.VALID.rvU(i)) .and. &
			(.VALID.rvV(i)) .and. &
			(.VALID.rvT(i)) .and. &
			(ivQ(i) >= STAT_SOUNDNESS_PERCENTAGE)
	end do
	
	! Prepare output file names
	WRITE(sProcessedFile, "(a, '/', i4.4, 2i2.2, '.', i2.2, 'o')") &
		TRIM(sDataPath), iYear, iMonth, iDay, iHour
	
	! OK, now the context is clear. Inform users, by writing configuration and
	! other data to file 'status.txt'
	OPEN(10, FILE='/mnt/ramdisk/status2d.txt', STATUS='UNKNOWN', ACTION='WRITE', IOSTAT=iRetCode)
	IF(iRetCode /= 0) THEN
		PRINT *,'proc2d:: warning: Impossible to write status file'
	ELSE
		CALL DATE_AND_TIME(Values=ivValues)
		WRITE(10, "('Started on ',i4.4,2('-',i2.2),' ',i2.2,2(':',i2.2))") ivValues(1:3), ivValues(5:7)
		WRITE(10, "('Proc time  ',i4.4,2('-',i2.2),' ',i2.2,2(':',i2.2))") iYear, iMonth, iDay, iHour, iMinute, iSecond
		WRITE(10, "('Passed date-time: ',a)") TRIM(sDateTime)
		WRITE(10, "('Time zone:        ',i2)") iFuse
		WRITE(10, "('Input file:       ',a)") TRIM(sInputFile)
		WRITE(10, "('Output file:      ',a)") TRIM(sProcessedFile)
		WRITE(10, "('Data on input:    ',i5)") COUNT(lvDesiredSubset)
		WRITE(10, "('Valid data   :    ',i5)") COUNT(lvValid)
		WRITE(10, "('Number of blocks: ',i2)") iMaxBlock
		WRITE(10, "('Epoch of current time: ',i2)") iHourBegin
	END IF
	FLUSH(10)

	! Main loop: process blocks, in order
	DO iBlock = 1, iMaxBlock
	
		WRITE(10, "(' ')")
		WRITE(10, "('--> Block ',i2)") iBlock
		FLUSH(10)
		
		! Assign block time stamp
		iBlockTime = iHourBegin + (iBlock-1)*iAveragingTime
		ivTimeStamp(iBlock) = iBlockTime
		CALL UnpackTime(iBlockTime, iBlockYear, iBlockMonth, iBlockDay, iBlockHour, iBlockMinute, iBlockSecond)
		WRITE(sBlockTime, "(i4.4,2('-',i2.2),1x,i2.2,2(':',i2.2))") &
			iBlockYear, iBlockMonth, iBlockDay, iBlockHour, iBlockMinute, iBlockSecond
		WRITE(10, "('    This block time: ',a)") TRIM(sBlockTime)
		
		! Delimit current block
		CALL GetTimeSubset(ivTime, iAveragingTime, iBlock, lvDesiredSubset, iRetCode)
		iTotData = count(lvDesiredSubset)
		lvDesiredSubset = lvDesiredSubset .AND. lvValid
		iValidData = count(lvDesiredSubset)
		ivTotData(iBlock) = iTotData
		ivUsedData(iBlock) = iValidData
		IF(COUNT(lvDesiredSubset) <= 0) THEN
			WRITE(10, "('    Warning: no data in block')")
			CYCLE
		END IF
		
		! Compute time stamp regularity indices
		CALL CheckTimeRegularity(ivTime, lvDesiredSubset, iFrequency, iRegularityCode, iRetCode)
		IF(iRetCode /= 0) THEN
			WRITE(10, "('    Warning: block skipped because of sonic data regularity problem (most likely cause: RTC glitch)')")
			CYCLE
		END IF
		FLUSH(10)
		ivFrequency(iBlock)      = iFrequency
		ivRegularityCode(iBlock) = iRegularityCode
		
		! Compute data ranges
		iRetCode = GetRange(rvU, lvDesiredSubset, rMinValue, rMaxValue)
		IF(iRetCode /= 0) CYCLE
		raMin(iBlock, 1) = rMinValue
		raMax(iBlock, 1) = rMaxValue
		iRetCode = GetRange(rvV, lvDesiredSubset, rMinValue, rMaxValue)
		raMin(iBlock, 2) = rMinValue
		raMax(iBlock, 2) = rMaxValue
		iRetCode = GetRange(rvT, lvDesiredSubset, rMinValue, rMaxValue)
		rvMinT(iBlock) = rMinValue
		rvMaxT(iBlock) = rMaxValue
		
		! Compute non-rotated averages and (co)variances
		CALL Average(rvU, lvDesiredSubset, raAvg(iBlock,1))
		CALL Average(rvV, lvDesiredSubset, raAvg(iBlock,2))
		CALL Average(rvT, lvDesiredSubset, rvAvgT(iBlock))
		CALL Covariance(rvU, rvU, lvDesiredSubset, raAvg(iBlock,1), raAvg(iBlock,1), raCov(iBlock,1,1))
		CALL Covariance(rvU, rvV, lvDesiredSubset, raAvg(iBlock,1), raAvg(iBlock,2), raCov(iBlock,1,2))
		CALL Covariance(rvV, rvV, lvDesiredSubset, raAvg(iBlock,2), raAvg(iBlock,2), raCov(iBlock,2,2))
		raCov(iBlock,2,1) = raCov(iBlock,1,2)
		CALL Covariance(rvU, rvT, lvDesiredSubset, raAvg(iBlock,1), rvAvgT(iBlock), raCovT(iBlock,1))
		CALL Covariance(rvV, rvT, lvDesiredSubset, raAvg(iBlock,2), rvAvgT(iBlock), raCovT(iBlock,2))
		CALL Covariance(rvT, rvT, lvDesiredSubset, rvAvgT(iBlock),  rvAvgT(iBlock), rvVarT(iBlock))
		
		! Compute non-turbulent wind statistics
		iRetCode = WindStatistics2D( &
			rvU, rvV, &
			lvDesiredSubset, &
			rvVectorVel(iBlock), &
			rvVectorDir(iBlock), &
			rvScalarVel(iBlock), &
			rvScalarVelStd(iBlock), &
			rvUnitVectorDir(iBlock), &
			rvEstSigmaDir(iBlock), &
			rvUnitVel(iBlock), &
			rvDirCircVar(iBlock), &
			rvDirCircStd(iBlock) &
		)
		IF(iRetCode /= 0) THEN
			rvVectorVel(iBlock)     = -9999.9
			rvVectorDir(iBlock)     = -9999.9
			rvScalarVel(iBlock)     = -9999.9
			rvScalarVelStd(iBlock)  = -9999.9
			rvUnitVectorDir(iBlock) = -9999.9
			rvEstSigmaDir(iBlock)   = -9999.9
			rvUnitVel(iBlock)       = -9999.9
			rvDirCircVar(iBlock)    = -9999.9
			rvDirCircStd(iBlock)    = -9999.9
		END IF
		iRetCode = WindDirClassify( &
			rvU, rvV, &
			lvDesiredSubset, &
			iaDirClass(iBlock,:), &
			rvDominantDir(iBlock) &
		)
		IF(iRetCode /= 0) THEN
			iaDirClass(iBlock,:)  = -9999
			rvDominantDir(iBlock) = -9999.9
		END IF
		
	END DO
	CLOSE(10)
	! ENDTAG: P9
	
	! TAG: P10
	! Write main result file
	OPEN(10, FILE=sProcessedFile, STATUS='UNKNOWN', ACTION='WRITE', IOSTAT=iRetCode)
	IF(iRetCode /= 0) THEN
		PRINT *,"proc2d:: error: Impossible to write main result file"
		STOP
	END IF
	WRITE(10,"(a,33(',',a))") &
		'Date.Time', 'Tot.Data', 'Valid.Data', &
		'Vel', 'Scalar.Vel', 'Scalar.Std', &
		'Dir', 'Unit.Vector.Dir', 'Yamartino.Std.Dir', &
		'Temp', &
		'Sigma.U', 'Sigma.V', 'Sigma.T', &
		'N.Dir.N', 'N.Dir.NNE', 'N.Dir.NE', 'N.Dir.ENE', &
		'N.Dir.E', 'N.Dir.ESE', 'N.Dir.SE', 'N.Dir.SSE', &
		'N.Dir.S', 'N.Dir.SSW', 'N.Dir.SW', 'N.Dir.WSW', &
		'N.Dir.W', 'N.Dir.WNW', 'N.Dir.NW', 'N.Dir.NNW', &
		'Dominant.Dir', &
		'Circ.Var', 'Circ.Std', 'U.Avg', 'V.Avg'
		
		! Write final data, provided "enough" raw data have been found on this
		! specific slice.
		iMaxTimeStamp = 0
		DO iBlock = 1, iMaxBlock
			CALL UnpackTime(ivTimeStamp(iBlock), iBlockYear, iBlockMonth, iBlockDay, iBlockHour, iBlockMinute, iBlockSecond)
			IF(ivTimeStamp(iBlock) > 0) THEN
				IF(ivUsedData(iBlock) > 1) THEN
					iMaxTimeStamp = MAX(iMaxTimeStamp, ivTimeStamp(iBlock))
					WRITE(10, "(i4.4,2('-',i2.2),1x,i2.2,2(':',i2.2),2(',',i6),10(',',f9.3),16(',',i6),5(',',f9.3))") &
						iBlockYear, iBlockMonth, iBlockDay, iBlockHour, iBlockMinute, iBlockSecond, &
						ivTotData(iBlock), ivUsedData(iBlock), &
						rvVectorVel(iBlock), rvScalarVel(iBlock), rvScalarVelStd(iBlock), &
						rvVectorDir(iBlock), rvUnitVectorDir(iBlock), rvEstSigmaDir(iBlock), &
						rvAvgT(iBlock), &
						rvSigmaU(iBlock), rvSigmaV(iBlock), rvSigmaT(iBlock), &
						iaDirClass(iBlock,:), rvDominantDir(iBlock), &
						rvDirCircVar(iBlock), rvDirCircStd(iBlock), &
						raAvg(iBlock,1), raAvg(iBlock,2)
				ELSE
					WRITE(10, "(i4.4,2('-',i2.2),1x,i2.2,2(':',i2.2),2(',',i6),10(',',f9.3),16(',',i6),5(',',f9.3))") &
						iBlockYear, iBlockMonth, iBlockDay, iBlockHour, iBlockMinute, iBlockSecond, &
						ivTotData(iBlock), ivUsedData(iBlock), &
						-9999.9, -9999.9, -9999.9, -9999.9, &
						-9999.9, -9999.9, -9999.9, &
						-9999.9, &
						-9999.9, -9999.9, &
						-9999, -9999, -9999, -9999, -9999, -9999, -9999, -9999, &
						-9999, -9999, -9999, -9999, -9999, -9999, -9999, -9999, &
						-9999.9, &
						-9999.9, -9999.9, -9999.9, -9999.9
				END IF
			END IF
		END DO
	CLOSE(10)
	
	! Copy main results file to local root for protocol gathering
	WRITE(sCommand, "('cp ',a,1x,a,'/CurData2D.csv')") TRIM(sProcessedFile), TRIM(sDataPath)
	CALL SYSTEM(sCommand)
	
	! Leave
	
CONTAINS
	
	FUNCTION ReadInputFile2D(iLUN, sInputFile, ivTime, rvU, rvV, rvT, ivQ) RESULT(iRetCode)
	
		! Routine arguments
		INTEGER, INTENT(IN)								:: iLUN
		CHARACTER(LEN=*), INTENT(IN)					:: sInputFile
		INTEGER, DIMENSION(:), ALLOCATABLE, INTENT(OUT)	:: ivTime
		REAL, DIMENSION(:), ALLOCATABLE, INTENT(OUT)	:: rvU
		REAL, DIMENSION(:), ALLOCATABLE, INTENT(OUT)	:: rvV
		REAL, DIMENSION(:), ALLOCATABLE, INTENT(OUT)	:: rvT
		INTEGER, DIMENSION(:), ALLOCATABLE, INTENT(OUT)	:: ivQ
		INTEGER											:: iRetCode
		
		! Locals
		INTEGER		:: iErrCode
		INTEGER		:: iNumData
		INTEGER		:: iData
		INTEGER(2)	:: iTimeStamp, iU, iV, iT, iQ
		
		! Assume success (will falsify on failure)
		iRetCode = 0
		
		! Count how many data are available, and reserve workspace based on this information
		OPEN(iLUN, FILE=sInputFile, STATUS='OLD', ACTION='READ', ACCESS='STREAM', IOSTAT=iErrCode)
		IF(iErrCode /= 0) THEN
			iRetCode = 1
			CLOSE(iLUN)
			print *,"Open non riuscita, codice ", iErrCode
			RETURN
		END IF
		iNumData = 0
		DO
			
			! Get data in binary form
			READ(10, IOSTAT=iErrCode) iTimeStamp, iV, iU, iT, iQ
			IF(iErrCode /= 0) EXIT
			iNumData = iNumData + 1
			
		END DO
		IF(iNumData <= 0) THEN
			iRetCode = 2
			CLOSE(iLUN)
			RETURN
		END IF
		ALLOCATE(ivTime(iNumData), rvU(iNumData), rvV(iNumData), rvT(iNumData), ivQ(iNumData))
		REWIND(iLUN)
		
		! Perform actual data read
		iData = 0
		DO
			
			! Get data in binary form
			READ(10, IOSTAT=iErrCode) iTimeStamp, iU, iV, iT, iQ
			IF(iErrCode /= 0) EXIT
			IF(iTimeStamp < 0) CYCLE
			iData = iData + 1
			ivTime(iData) = iTimeStamp
			IF(iU > -9990 .AND. iV > -9990 .AND. iT > -9990 .AND. iQ > -9990) THEN
				rvU(iData) = iU / 100.
				rvV(iData) = iV / 100.
				rvT(iData) = iT / 100.
				ivQ(iData) = iQ
			ELSE
				rvU(iData) = -9999.9
				rvV(iData) = -9999.9
				rvT(iData) = -9999.9
				ivQ(iData) = -9999
			END IF
			
		END DO
		CLOSE(iLUN)
		
	END FUNCTION ReadInputFile2D

END PROGRAM eddy_cov

