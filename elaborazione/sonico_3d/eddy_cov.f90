PROGRAM eddy_cov

	USE SonicLib
	USE Calendar

	IMPLICIT NONE
	
	! Locals
	CHARACTER(LEN=256)		:: sIniFile
	CHARACTER(LEN=256)		:: sDataPath
	CHARACTER(LEN=256)		:: sToFile
	CHARACTER(LEN=256)		:: sInputFile
	CHARACTER(LEN=256)		:: sProcessedFile
	CHARACTER(LEN=256)		:: sDiagnosticFile
	CHARACTER(LEN=2048)		:: sCommand
	CHARACTER(LEN=20)		:: sDateTime
	CHARACTER(LEN=20)		:: sAvgTime
	CHARACTER(LEN=20)		:: sFuse
	INTEGER					:: iFuse
	INTEGER					:: iRetCode
	INTEGER, DIMENSION(10)	:: ivValues
	INTEGER					:: iAveragingTime
	LOGICAL					:: lDetrending
	INTEGER					:: iRotations
	REAL					:: rAltitude
	REAL					:: rAnemometerHeight
	INTEGER					:: iYear, iMonth, iDay, iHour, iMinute, iSecond
	INTEGER					:: iYear1, iMonth1, iDay1, iHour1, iMinute1, iSecond1
	INTEGER					:: iBlockYear, iBlockMonth, iBlockDay, iBlockHour, iBlockMinute, iBlockSecond
	CHARACTER(LEN=20)		:: sBlockTime
	INTEGER					:: iBlockTime
	LOGICAL					:: lIsFile
	INTEGER					:: i
	INTEGER, DIMENSION(:), ALLOCATABLE	:: ivTime
	REAL, DIMENSION(:), ALLOCATABLE		:: rvU
	REAL, DIMENSION(:), ALLOCATABLE		:: rvV
	REAL, DIMENSION(:), ALLOCATABLE		:: rvW
	REAL, DIMENSION(:), ALLOCATABLE		:: rvT
	LOGICAL, DIMENSION(:), ALLOCATABLE	:: lvDesiredSubset
	LOGICAL, DIMENSION(:), ALLOCATABLE	:: lvValid
	REAL, DIMENSION(:), ALLOCATABLE		:: rvTrendlessU
	REAL, DIMENSION(:), ALLOCATABLE		:: rvTrendlessV
	REAL, DIMENSION(:), ALLOCATABLE		:: rvTrendlessW
	REAL, DIMENSION(:), ALLOCATABLE		:: rvTrendlessT
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
	REAL, DIMENSION(3,3)				:: rmRot
	REAL, DIMENSION(3,1)				:: rmAux
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
	REAL, DIMENSION(:,:), ALLOCATABLE		:: raRotAvg		! Wind components averages, rotated
	REAL, DIMENSION(:), ALLOCATABLE			:: rvAvgT		! Temperature average
	REAL, DIMENSION(:), ALLOCATABLE			:: rvVarT		! Temperature standard deviation
	REAL, DIMENSION(:,:,:), ALLOCATABLE		:: raCov		! Wind components covariances, non rotated
	REAL, DIMENSION(:,:,:), ALLOCATABLE		:: raRotCov		! Wind components covariances, rotated
	REAL, DIMENSION(:,:), ALLOCATABLE		:: raCovT		! Wind-Temperature covariances, non rotated
	REAL, DIMENSION(:,:), ALLOCATABLE		:: raRotCovT	! Wind-Temperature covariances, rotated
	REAL, DIMENSION(:), ALLOCATABLE			:: rvTheta		! First rotation angle
	REAL, DIMENSION(:), ALLOCATABLE			:: rvPhi		! Second rotation angle
	REAL, DIMENSION(:), ALLOCATABLE			:: rvPsi		! Third rotation angle
	REAL, DIMENSION(:), ALLOCATABLE			:: rvVectorVel
	REAL, DIMENSION(:), ALLOCATABLE			:: rvVectorDir
	REAL, DIMENSION(:), ALLOCATABLE			:: rv3DVel
	REAL, DIMENSION(:), ALLOCATABLE			:: rvScalarVel
	REAL, DIMENSION(:), ALLOCATABLE			:: rvScalarVelStd
	REAL, DIMENSION(:), ALLOCATABLE			:: rvUnitVectorDir
	REAL, DIMENSION(:), ALLOCATABLE			:: rvEstSigmaDir
	REAL, DIMENSION(:), ALLOCATABLE			:: rvPhiAngle
	REAL, DIMENSION(:), ALLOCATABLE			:: rvSigmaPhiAngle
	REAL, DIMENSION(:), ALLOCATABLE			:: rvUnitVel
	REAL, DIMENSION(:), ALLOCATABLE			:: rvDirCircVar
	REAL, DIMENSION(:), ALLOCATABLE			:: rvDirCircStd
	INTEGER, DIMENSION(:,:), ALLOCATABLE	:: iaDirClass
	REAL, DIMENSION(:), ALLOCATABLE			:: rvDominantDir
	REAL, DIMENSION(:), ALLOCATABLE			:: rvUstar
	REAL, DIMENSION(:), ALLOCATABLE			:: rvUstarBase
	REAL, DIMENSION(:), ALLOCATABLE			:: rvUstarExtended
	REAL, DIMENSION(:), ALLOCATABLE			:: rvTstar
	REAL, DIMENSION(:), ALLOCATABLE			:: rvH0
	REAL, DIMENSION(:), ALLOCATABLE			:: rvZl
	REAL, DIMENSION(:), ALLOCATABLE			:: rvTKE
	REAL, DIMENSION(:), ALLOCATABLE			:: rvSigmaU
	REAL, DIMENSION(:), ALLOCATABLE			:: rvSigmaV
	REAL, DIMENSION(:), ALLOCATABLE			:: rvSigmaW
	REAL, DIMENSION(:), ALLOCATABLE			:: rvSigmaT
	
	NAMELIST /EddyConfig/ lDetrending, iRotations, rAltitude, rAnemometerHeight

	OPEN(101, FILE="/mnt/logs/eddy_cov.log", STATUS="UNKNOWN", ACTION="WRITE")
	WRITE(101,"('Starting execution')")
	
	! TAG: P1
	! Get input parameters
	IF(COMMAND_ARGUMENT_COUNT() /= 5) THEN
		PRINT *,'eddy_cov - Program implementing simple classical eddy covariance'
		PRINT *
		PRINT *,'Usage:'
		PRINT *
		PRINT *,'  ./eddy_cov <IniFile> <DataPath> <DateTime> <AvgTime> <Fuse>'
		PRINT *
		PRINT *,'Configuration file, <IniFile>, in eddy_cov namelist format.'
		PRINT *,'Averaging time, <AvgTime>, in seconds'
		PRINT *
		PRINT *,'Copyright 2012 by Servizi Territorio srl'
		PRINT *,'                  All rights reserved'
		PRINT *
		PRINT *,'Program "eddy_cov" is based on SonicLib open source ultrasonic'
		PRINT *,'data processing library. SonicLib is copyright by Università'
		PRINT *,'Statale di Milano, under license LGPL 2.0'
		PRINT *
		STOP
	END IF
	CALL GET_COMMAND_ARGUMENT(1, sIniFile)
	CALL GET_COMMAND_ARGUMENT(2, sDataPath)
	CALL GET_COMMAND_ARGUMENT(3, sDateTime)
	CALL GET_COMMAND_ARGUMENT(4, sAvgTime)
	READ(sAvgTime, *, IOSTAT=iRetCode) iAveragingTime
	IF(iRetCode /= 0) THEN
		PRINT *,'eddy_cov:: error: Invalid averaging time'
		STOP
	END IF
	CALL GET_COMMAND_ARGUMENT(5, sFuse)
	READ(sFuse, *, IOSTAT=iRetCode) iFuse
	IF(iRetCode /= 0) THEN
		PRINT *,'eddy_cov:: error: Invalid fuse'
		STOP
	END IF
	WRITE(101,"('Parameters read:')")
	WRITE(101,"('  Ini file:   ',a)") TRIM(sIniFile)
	WRITE(101,"('  Data path:  ',a)") TRIM(sDataPath)
	WRITE(101,"('  Tm stamp:   ',a)") TRIM(sDateTime)
	WRITE(101,"('  Avg time:   ',i5)") iAveragingTime
	WRITE(101,"('  Fuse:       ',i2)") iFuse
	! ENDTAG: P1
	
	! TAG: P2
	! Get current date and time, for diagnostic purposes
	CALL DATE_AND_TIME(VALUES=ivValues)
	WRITE(101,"('System date/time on activation: ',i4.4,2('-',i2.2),1x,i2.2,2(':',i2.2))") &
		ivValues(1), ivValues(2), ivValues(3), ivValues(5), ivValues(6), ivValues(7)
	FLUSH(101)
	! ENDTAG: P2

	! TAG: P3
	! Get configuration data (see NAMELIST declaration for details)
	OPEN(10, FILE=sIniFile, STATUS='OLD', ACTION='READ', IOSTAT=iRetCode)
	IF(iRetCode /= 0) THEN
		PRINT *,'eddy_cov:: error: Initialization file not accessible (nonexistent?)'
		STOP
	END IF
	READ(10, EddyConfig, IOSTAT=iRetCode)
	IF(iRetCode /= 0) THEN
		PRINT *,'eddy_cov:: error: Invalid initialization file ', iRetCode
		STOP
	END IF
	CLOSE(10)
	WRITE(101,"('Configuration data read:')")
	WRITE(101,"('  Trend removed? ',l1)") lDetrending
	WRITE(101,"('  Rotations:     ',i1)") iRotations
	WRITE(101,"('  Altitude:      ',f6.1)") rAltitude
	WRITE(101,"('  An.height:     ',f5.1)") rAnemometerHeight
	FLUSH(101)
	! ENDTAG: P3

	! TAG: P4
	! Build input file name, expected to be in sDataPath (on ram disk)
	READ(sDateTime, "(i4,5(1x,i2))", IOSTAT=iRetCode) iYear, iMonth, iDay, iHour, iMinute, iSecond
	IF(iRetCode /= 0) THEN
		PRINT *,'eddy_cov:: error: Invalid start of acquisition block'
		STOP
	END IF
	WRITE(sInputFile, "(a, '/', i4.4, 2i2.2, '.', i2.2, 'R')") &
		TRIM(sDataPath), iYear, iMonth, iDay, iHour
	INQUIRE(FILE=sInputFile, EXIST=lIsFile)
	IF(.NOT.lIsFile) THEN
		PRINT *,'eddy_cov:: error: Input file, ',TRIM(sInputFile),', not found'
		STOP
	END IF
	WRITE(101,"('Date to process and its data file(s)')")
	WRITE(101,"('  Date / time to process: ', a)") sDateTime
	WRITE(101,"('  Input file name : ', a)") TRIM(sInputFile)
	FLUSH(101)
	! ENDTAG: P4
	
	! TAG: P5
	! Compute number of blocks to process, and reserve block-related workspace
	CALL PackTime(iCurTime, iYear, iMonth, iDay, iHour, iMinute, iSecond)
	CALL PackTime(iHourBegin, iYear, iMonth, iDay, iHour, 0, 0)
	iMaxBlock = (iCurTime - iHourBegin) / iAveragingTime + 1
	WRITE(101,"('Blocks to process: ',i2)") iMaxBlock
	ALLOCATE( &
		ivTimeStamp(iMaxBlock), ivFrequency(iMaxBlock), ivRegularityCode(iMaxBlock), &
		ivTotData(iMaxBlock), ivUsedData(iMaxBlock), &
		raMin(iMaxBlock,3), raMax(iMaxBlock,3), &
		rvMinT(iMaxBlock), rvMaxT(iMaxBlock), &
		raAvg(iMaxBlock,3), raRotAvg(iMaxBlock,3), &
		rvAvgT(iMaxBlock), rvVarT(iMaxBlock), &
		raCov(iMaxBlock,3,3), raRotCov(iMaxBlock,3,3), &
		raCovT(iMaxBlock,3), raRotCovT(iMaxBlock,3), &
		rvTheta(iMaxBlock), rvPhi(iMaxBlock), rvPsi(iMaxBlock), &
		rvVectorVel(iMaxBlock), rvVectorDir(iMaxBlock), rv3DVel(iMaxBlock), &
		rvScalarVel(iMaxBlock), rvScalarVelStd(iMaxBlock), &
		rvUnitVectorDir(iMaxBlock), rvEstSigmaDir(iMaxBlock), &
		rvPhiAngle(iMaxBlock), rvSigmaPhiAngle(iMaxBlock), &
		rvUnitVel(iMaxBlock), rvDirCircVar(iMaxBlock), rvDirCircStd(iMaxBlock), &
		iaDirClass(iMaxBlock, 16), rvDominantDir(iMaxBlock), &
		rvUstarBase(iMaxBlock), rvUstarExtended(iMaxBlock), &
		rvUstar(iMaxBlock), rvTstar(iMaxBlock), rvH0(iMaxBlock), &
		rvZl(iMaxBlock), rvTKE(iMaxBlock), &
		rvSigmaU(iMaxBlock), rvSigmaV(iMaxBlock), rvSigmaW(iMaxBlock), rvSigmaT(iMaxBlock) &
	)
	! ENDTAG: P5
	
	! TAG: P6
	! Get input file
	iRetCode = ReadInputFile(10, sInputFile, ivTime, rvU, rvV, rvW, rvT)
	IF(iRetCode /= 0) THEN
		PRINT *,'eddy_cov:: error: Input file not read (empty or missing)'
		STOP
	END IF
	ALLOCATE( &
		rvTrendlessU(SIZE(rvU)), rvTrendlessV(SIZE(rvV)), rvTrendlessW(SIZE(rvW)), rvTrendlessT(SIZE(rvT)), &
		lvDesiredSubset(SIZE(ivTime)), lvValid(SIZE(ivTime)) &
	)
	rvTrendlessU = -9999.9
	rvTrendlessV = -9999.9
	rvTrendlessW = -9999.9
	rvTrendlessT = -9999.9
	WRITE(101,"('Input file read')")
	! ENDTAG: P6
	
	! TAG: P7
	! Which data are valid?
	do i = 1, size(ivTime)
		lvValid(i) = (.VALID.rvU(i)) .or. (.VALID.rvV(i)) .or. (.VALID.rvW(i)) .or. (.VALID.rvT(i))
	end do
	WRITE(101,"('Valid data counted')")
	! ENDTAG: P7
	
	! Prepare output file names
	WRITE(sProcessedFile, "(a, '/', i4.4, 2i2.2, '.', i2.2, 'p')") &
		TRIM(sDataPath), iYear, iMonth, iDay, iHour
	WRITE(sDiagnosticFile, "(a, '/', i4.4, 2i2.2, '.', i2.2, 'd')") &
		TRIM(sDataPath), iYear, iMonth, iDay, iHour
	WRITE(101,"('Output file names defined:')")
	WRITE(101,"('  Processed data:  ',a)") TRIM(sProcessedFile)
	WRITE(101,"('  Diagnostic data: ',a)") TRIM(sDiagnosticFile)
	
	! TAG: P8
	! OK, now the context is clear. Inform users, by writing configuration and
	! other data to file 'status.txt'
	OPEN(10, FILE='/mnt/ramdisk/status.txt', STATUS='UNKNOWN', ACTION='WRITE', IOSTAT=iRetCode)
	IF(iRetCode /= 0) THEN
		PRINT *,'eddy_cov:: warning: Impossible to write status file'
	ELSE
		CALL DATE_AND_TIME(Values=ivValues)
		WRITE(10, "('Started on ',i4.4,2('-',i2.2),' ',i2.2,2(':',i2.2))") ivValues(1:3), ivValues(5:7)
		WRITE(10, "('Proc time  ',i4.4,2('-',i2.2),' ',i2.2,2(':',i2.2))") iYear, iMonth, iDay, iHour, iMinute, iSecond
		WRITE(10, "('Passed date-time: ',a)") TRIM(sDateTime)
		WRITE(10, "('Time zone:        ',i2)") iFuse
		WRITE(10, "('Input file:       ',a)") TRIM(sInputFile)
		WRITE(10, "('Output file:      ',a)") TRIM(sProcessedFile)
		WRITE(10, "('Diag file:        ',a)") TRIM(sDiagnosticFile)
		WRITE(10, "('Data on input:    ',i5)") COUNT(lvDesiredSubset)
		WRITE(10, "('Number of blocks: ',i2)") iMaxBlock
		WRITE(10, "('Epoch of current time: ',i2)") iHourBegin
	END IF
	FLUSH(10)
	! ENDTAG: P8

	! TAG: P9
	! Main loop: process blocks, in order
	DO iBlock = 1, iMaxBlock
	
		WRITE(10, "(' ')")
		WRITE(10, "('--> Now processing block ',i2)") iBlock
		FLUSH(10)
		
		! TAG: P9.2
		! Assign block time stamp
		iBlockTime = iHourBegin + (iBlock-1)*iAveragingTime
		ivTimeStamp(iBlock) = iBlockTime
		CALL UnpackTime(iBlockTime, iBlockYear, iBlockMonth, iBlockDay, iBlockHour, iBlockMinute, iBlockSecond)
		WRITE(sBlockTime, "(i4.4,2('-',i2.2),1x,i2.2,2(':',i2.2))") &
			iBlockYear, iBlockMonth, iBlockDay, iBlockHour, iBlockMinute, iBlockSecond
		WRITE(10, "('    This block time: ',a)") TRIM(sBlockTime)
		! ENDTAG: P9.2
		
		! TAG: P9.1
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
		! ENDTAG: P9.1
		
		! TAG: P9.3
		! Compute time stamp regularity indices
		CALL CheckTimeRegularity(ivTime, lvDesiredSubset, iFrequency, iRegularityCode, iRetCode)
		IF(iRetCode /= 0) THEN
			WRITE(10, "('    Warning: block skipped because of sonic data regularity problem (most likely cause: RTC glitch)')")
			CYCLE
		END IF
		FLUSH(10)
		ivFrequency(iBlock)      = iFrequency
		ivRegularityCode(iBlock) = iRegularityCode
		! ENDTAG: P9.3
		
		! TAG: P9.4
		! Compute data ranges
		iRetCode = GetRange(rvU, lvDesiredSubset, rMinValue, rMaxValue)
		IF(iRetCode /= 0) CYCLE
		raMin(iBlock, 1) = rMinValue
		raMax(iBlock, 1) = rMaxValue
		iRetCode = GetRange(rvV, lvDesiredSubset, rMinValue, rMaxValue)
		raMin(iBlock, 2) = rMinValue
		raMax(iBlock, 2) = rMaxValue
		iRetCode = GetRange(rvW, lvDesiredSubset, rMinValue, rMaxValue)
		raMin(iBlock, 3) = rMinValue
		raMax(iBlock, 3) = rMaxValue
		iRetCode = GetRange(rvT, lvDesiredSubset, rMinValue, rMaxValue)
		rvMinT(iBlock) = rMinValue
		rvMaxT(iBlock) = rMaxValue
		! ENDTAG: P9.4
		
		! TAG: P9.5
		! Remove trend, if requested
		IF(lDetrending .AND. iRegularityCode >= 3) THEN
			CALL RemoveLinearTrend( &
				ivTime, &
				rvU, rvV, rvW, rvT, &
				iFrequency, &
				lvDesiredSubset, &
				rvTrendlessU, rvTrendlessV, rvTrendlessW, rvTrendlessT, &
				iRetCode &
			)
		ELSE
			WHERE(lvDesiredSubset)
				rvTrendlessU = rvU
				rvTrendlessV = rvV
				rvTrendlessW = rvW
				rvTrendlessT = rvT
			ENDWHERE
		END IF
		! ENDTAG: P9.5
	
		! TAG: P9.6
		! Compute non-rotated averages and (co)variances
		CALL Average(rvTrendlessU, lvDesiredSubset, raAvg(iBlock,1))
		CALL Average(rvTrendlessV, lvDesiredSubset, raAvg(iBlock,2))
		CALL Average(rvTrendlessW, lvDesiredSubset, raAvg(iBlock,3))
		CALL Average(rvTrendlessT, lvDesiredSubset, rvAvgT(iBlock))
		CALL Covariance(rvTrendlessU, rvTrendlessU, lvDesiredSubset, raAvg(iBlock,1), raAvg(iBlock,1), raCov(iBlock,1,1))
		CALL Covariance(rvTrendlessU, rvTrendlessV, lvDesiredSubset, raAvg(iBlock,1), raAvg(iBlock,2), raCov(iBlock,1,2))
		CALL Covariance(rvTrendlessU, rvTrendlessW, lvDesiredSubset, raAvg(iBlock,1), raAvg(iBlock,3), raCov(iBlock,1,3))
		CALL Covariance(rvTrendlessV, rvTrendlessV, lvDesiredSubset, raAvg(iBlock,2), raAvg(iBlock,2), raCov(iBlock,2,2))
		CALL Covariance(rvTrendlessV, rvTrendlessW, lvDesiredSubset, raAvg(iBlock,2), raAvg(iBlock,3), raCov(iBlock,2,3))
		CALL Covariance(rvTrendlessW, rvTrendlessW, lvDesiredSubset, raAvg(iBlock,3), raAvg(iBlock,3), raCov(iBlock,3,3))
		raCov(iBlock,2,1) = raCov(iBlock,1,2)
		raCov(iBlock,3,1) = raCov(iBlock,1,3)
		raCov(iBlock,3,2) = raCov(iBlock,2,3)
		rvTKE(iBlock)     = (raCov(iBlock,1,1) + raCov(iBlock,2,2) + raCov(iBlock,3,3)) / 2.0
		CALL Covariance(rvTrendlessU, rvTrendlessT, lvDesiredSubset, raAvg(iBlock,1), rvAvgT(iBlock), raCovT(iBlock,1))
		CALL Covariance(rvTrendlessV, rvTrendlessT, lvDesiredSubset, raAvg(iBlock,2), rvAvgT(iBlock), raCovT(iBlock,2))
		CALL Covariance(rvTrendlessW, rvTrendlessT, lvDesiredSubset, raAvg(iBlock,3), rvAvgT(iBlock), raCovT(iBlock,3))
		CALL Covariance(rvTrendlessT, rvTrendlessT, lvDesiredSubset, rvAvgT(iBlock),  rvAvgT(iBlock), rvVarT(iBlock))
		! ENDTAG: P9.6
		
		! TAG: P9.7
		! Perform axis rotation
		rmRot = RotationMatrix(iRotations, raAvg(iBlock,:), raCov(iBlock,:,:), rvTheta(iBlock), rvPhi(iBlock), rvPsi(iBlock))
		rmAux                = MATMUL(rmRot,RESHAPE(raAvg(iBlock,:),(/3,1/)))
		raRotAvg(iBlock,:)   = rmAux(:,1)
		raRotCov(iBlock,:,:) = MATMUL(MATMUL(rmRot,raCov(iBlock,:,:)),TRANSPOSE(rmRot))
		rmAux                = MATMUL(rmRot,RESHAPE(raCovT(iBlock,:),(/3,1/)))
		raRotCovT(iBlock,:)  = rmAux(:,1)
		! ENDTAG: P9.7
		
		! TAG: P9.8
		! Compute non-turbulent wind statistics
		iRetCode = WindStatistics( &
			rvTrendlessU, rvTrendlessV, rvTrendlessW, &
			lvDesiredSubset, &
			rvVectorVel(iBlock), &
			rvVectorDir(iBlock), &
			rv3DVel(iBlock), &
			rvScalarVel(iBlock), &
			rvScalarVelStd(iBlock), &
			rvUnitVectorDir(iBlock), &
			rvEstSigmaDir(iBlock), &
			rvPhiAngle(iBlock), &	
			rvSigmaPhiAngle(iBlock), &
			rvUnitVel(iBlock), &
			rvDirCircVar(iBlock), &
			rvDirCircStd(iBlock) &
		)
		IF(iRetCode /= 0) THEN
			rvVectorVel(iBlock)     = -9999.9
			rvVectorDir(iBlock)     = -9999.9
			rv3DVel(iBlock)         = -9999.9
			rvScalarVel(iBlock)     = -9999.9
			rvScalarVelStd(iBlock)  = -9999.9
			rvUnitVectorDir(iBlock) = -9999.9
			rvEstSigmaDir(iBlock)   = -9999.9
			rvPhiAngle(iBlock)      = -9999.9
			rvSigmaPhiAngle(iBlock) = -9999.9
			rvUnitVel(iBlock)       = -9999.9
			rvDirCircVar(iBlock)    = -9999.9
			rvDirCircStd(iBlock)    = -9999.9
		END IF
		iRetCode = WindDirClassify( &
			rvTrendlessU, rvTrendlessV, &
			lvDesiredSubset, &
			iaDirClass(iBlock,:), &
			rvDominantDir(iBlock) &
		)
		IF(iRetCode /= 0) THEN
			iaDirClass(iBlock,:)  = -9999
			rvDominantDir(iBlock) = -9999.9
		END IF
		! ENDTAG: P9.8
		
		! TAG: P9.9
		! Compute turbulence indices
		iRetCode = BasicTurbulence( &
			rAltitude, &
			rAnemometerHeight, &
			rvAvgT(iBlock), &
			raRotCov(iBlock,:,:), &
			raRotCovT(iBlock,:), &
			rvVarT(iBlock), &
			rvUstar(iBlock), &
			rvTstar(iBlock), &
			rvH0(iBlock), &
			rvZl(iBlock), &
			rvTKE(iBlock), &
			rvSigmaU(iBlock), &
			rvSigmaV(iBlock), &
			rvSigmaW(iBlock), &
			rvSigmaT(iBlock) &
		)
		IF(iRetCode == 0) THEN
			rvUstarBase(iBlock) = SIGN( &
				SQRT(ABS(raRotCov(iBlock,1,3))), &
				raRotCov(iBlock,1,3) &
			)
			rvUstarExtended(iBlock) = SIGN( &
				(raRotCov(iBlock,1,3)**2 + raRotCov(iBlock,2,3)**2)**0.25, &
				raRotCov(iBlock,1,3) &
			)
		ELSE
			rvAvgT(iBlock)          = -9999.9
			raRotCov(iBlock,:,:)    = -9999.9
			rvUstar(iBlock)         = -9999.9
			rvUstarBase(iBlock)     = -9999.9
			rvUstarExtended(iBlock) = -9999.9
			rvTstar(iBlock)         = -9999.9
			rvH0(iBlock)            = -9999.9
			rvZl(iBlock)            = -9999.9
			rvTKE(iBlock)           = -9999.9
			rvSigmaU(iBlock)        = -9999.9
			rvSigmaV(iBlock)        = -9999.9
			rvSigmaW(iBlock)        = -9999.9
			rvSigmaT(iBlock)        = -9999.9
		END IF
		! ENDTAG: P9.9
		
	END DO
	CLOSE(10)
	! ENDTAG: P9
	
	! TAG: P10
	! Write main result file
	OPEN(10, FILE=sProcessedFile, STATUS='UNKNOWN', ACTION='WRITE', IOSTAT=iRetCode)
	IF(iRetCode /= 0) THEN
		PRINT *,"eddy_cov:: error: Impossible to write main result file"
		STOP
	END IF
	WRITE(10,"(a,31(',',a))") &
		'Date.Time', 'Tot.Data', 'Valid.Data', &
		'Vel', 'Vector.Vel', 'Scalar.Vel', 'Scalar.Std', &
		'Dir', 'Unit.Vector.Dir', 'Yamartino.Std.Dir', &
		'Temp', &
		'Phi.Angle', 'Sigma.Phi.Angle', &
		'Sigma.U', 'Sigma.V', 'Sigma.W', 'Sigma.T', &
		'Theta', 'Phi', 'Psi', &
		'TKE', 'U.star', 'T.star', 'z.L', &
		'H0', 'H0.Plus.Density.Effect', 'He', &
		'Eff.W', 'Q', 'C', 'Fq', 'Fc'
		
		! Write final data, provided "enough" raw data have been found on this
		! specific slice.
		iMaxTimeStamp = 0
		DO iBlock = 1, iMaxBlock
			CALL UnpackTime(ivTimeStamp(iBlock), iBlockYear, iBlockMonth, iBlockDay, iBlockHour, iBlockMinute, iBlockSecond)
			IF(ivTimeStamp(iBlock) > 0) THEN
				IF(ivUsedData(iBlock) > 1) THEN
					iMaxTimeStamp = MAX(iMaxTimeStamp, ivTimeStamp(iBlock))
					WRITE(10, "(i4.4,2('-',i2.2),1x,i2.2,2(':',i2.2),2(',',i6),20(',',f9.3),',',e15.7,8(',',f9.3))") &
						iBlockYear, iBlockMonth, iBlockDay, iBlockHour, iBlockMinute, iBlockSecond, &
						ivTotData(iBlock), ivUsedData(iBlock), &
						rvVectorVel(iBlock), rv3DVel(iBlock), rvScalarVel(iBlock), rvScalarVelStd(iBlock), &
						rvVectorDir(iBlock), rvUnitVectorDir(iBlock), rvEstSigmaDir(iBlock), &
						rvAvgT(iBlock), &
						rvPhiAngle(iBlock), rvSigmaPhiAngle(iBlock), &	
						rvSigmaU(iBlock), rvSigmaV(iBlock), rvSigmaW(iBlock), rvSigmaT(iBlock), &
						rvTheta(iBlock), rvPhi(iBlock), rvPsi(iBlock), &
						rvTKE(iBlock), rvUstar(iBlock), rvTstar(iBlock), rvZl(iBlock), rvH0(iBlock), -9999.9, -9999.9, &
						-9999.9, -9999.9, -9999.9, -9999.9, -9999.9	
				ELSE
					WRITE(10, "(i4.4,2('-',i2.2),1x,i2.2,2(':',i2.2),2(',',i6),20(',',f9.3),',',e15.7,8(',',f9.3))") &
						iBlockYear, iBlockMonth, iBlockDay, iBlockHour, iBlockMinute, iBlockSecond, &
						ivTotData(iBlock), ivUsedData(iBlock), &
						-9999.9, -9999.9, -9999.9, -9999.9, &
						-9999.9, -9999.9, -9999.9, &
						-9999.9, &
						-9999.9, -9999.9, &
						-9999.9, -9999.9, -9999.9, -9999.9, &
						-9999.9, -9999.9, -9999.9, &
						-9999.9, -9999.9, -9999.9, -9999.9, -9999.9, -9999.9, -9999.9, &
						-9999.9, -9999.9, -9999.9, -9999.9, -9999.9
				END IF
			END IF
		END DO
	CLOSE(10)
	! ENDTAG: P10
	
	! TAG: P11
	! Copy main results file to local root for protocol gathering
	WRITE(sCommand, "('cp ',a,1x,a,'/CurData.csv')") TRIM(sProcessedFile), TRIM(sDataPath)
	CALL SYSTEM(sCommand)
	! ENDTAG: P11
	
	! TAG: P12
	! Write diagnostic file
	OPEN(10, FILE=sDiagnosticFile, STATUS='UNKNOWN', ACTION='WRITE', IOSTAT=iRetCode)
	IF(iRetCode /= 0) THEN
		PRINT *,"eddy_cov:: error: Impossible to write diagnostic file"
		STOP
	END IF
	WRITE(10,"(a,66(',',a))") &
		'Date.Time', 'Tot.Data', 'Valid.Data', &
		'N.Dir.N', 'N.Dir.NNE', 'N.Dir.NE', 'N.Dir.ENE', &
		'N.Dir.E', 'N.Dir.ESE', 'N.Dir.SE', 'N.Dir.SSE', &
		'N.Dir.S', 'N.Dir.SSW', 'N.Dir.SW', 'N.Dir.WSW', &
		'N.Dir.W', 'N.Dir.WNW', 'N.Dir.NW', 'N.Dir.NNW', &
		'Dominant.Dir', &
		'Vel', 'Dir', 'U', 'V', 'W', 'T', 'r', 'Circ.Var', 'Circ.Std', &
		'Range.U', 'Range.V', 'Range.W', 'Range.T', &
		'Nrot.Sigma2.U', 'Nrot.Sigma2.V', 'Nrot.Sigma2.W', &
		'Nrot.Cov.UV', 'Nrot.Cov.UW', 'Nrot.Cov.VW', &
		'Nrot.Cov.UT', 'Nrot.Cov.VT', 'Nrot.Cov.WT', &
		'Rot.Sigma2.U', 'Rot.Sigma2.V', 'Rot.Sigma2.W', &
		'Rot.Cov.UV', 'Rot.Cov.UW', 'Rot.Cov.VW', &
		'Rot.Cov.UT', 'Rot.Cov.VT', 'Rot.Cov.WT', &
		'Ustar.Base', 'Ustar.Extended', &
		'Theta', 'Phi', 'Psi', &
		'Eff.W', 'Q', 'C'
		DO iBlock = 1, iMaxBlock
			IF(ivTimeStamp(iBlock) > 0) THEN
				CALL UnpackTime(ivTimeStamp(iBlock), iBlockYear, iBlockMonth, iBlockDay, iBlockHour, iBlockMinute, iBlockSecond)
				IF(ivUsedData(iBlock) > 1) THEN
					WRITE(10, "(i4.4,2('-',i2.2),1x,i2.2,2(':',i2.2),18(',',i6),40(',',f9.3))") &
						iBlockYear, iBlockMonth, iBlockDay, iBlockHour, iBlockMinute, iBlockSecond, &
						ivTotData(iBlock), ivUsedData(iBlock), &
						iaDirClass(iBlock,:), rvDominantDir(iBlock), &
						rvVectorVel(iBlock), rvVectorDir(iBlock), &
						raAvg(iBlock,:), rvAvgT(iBlock), &
						rvUnitVel(iBlock), rvDirCircVar(iBlock), rvDirCircStd(iBlock), &
						raMax(iBlock,:) - raMin(iBlock,:), rvMaxT(iBlock) - rvMinT(iBlock), &
						raCov(iBlock,1,1), &
						raCov(iBlock,2,2), &
						raCov(iBlock,3,3), &
						raCov(iBlock,1,2), &
						raCov(iBlock,1,3), &
						raCov(iBlock,2,3), &
						raCovT(iBlock,1), &
						raCovT(iBlock,2), &
						raCovT(iBlock,3), &
						raRotCov(iBlock,1,1), &
						raRotCov(iBlock,2,2), &
						raRotCov(iBlock,3,3), &
						raRotCov(iBlock,1,2), &
						raRotCov(iBlock,1,3), &
						raRotCov(iBlock,2,3), &
						raRotCovT(iBlock,1), &
						raRotCovT(iBlock,2), &
						raRotCovT(iBlock,3), &
						rvUstarBase(iBlock), rvUstarExtended(iBlock), &
						rvTheta(iBlock), rvPhi(iBlock), rvPsi(iBlock), &
						-9999.9, -9999.9, -9999.9
				ELSE
					WRITE(10, "(i4.4,2('-',i2.2),1x,i2.2,2(':',i2.2),18(',',i6),40(',',f9.3))") &
						iBlockYear, iBlockMonth, iBlockDay, iBlockHour, iBlockMinute, iBlockSecond, &
						ivTotData(iBlock), ivUsedData(iBlock), &
						-9999, -9999, -9999, -9999, -9999, -9999, -9999, -9999, &
						-9999, -9999, -9999, -9999, -9999, -9999, -9999, -9999, &
						-9999.9, -9999.9, -9999.9, -9999.9, -9999.9, -9999.9, -9999.9, &
						-9999.9, -9999.9, -9999.9, -9999.9, -9999.9, -9999.9, -9999.9, &
						-9999.9, -9999.9, -9999.9, -9999.9, -9999.9, -9999.9, -9999.9, -9999.9, -9999.9, &
						-9999.9, -9999.9, -9999.9, -9999.9, -9999.9, -9999.9, -9999.9, -9999.9, -9999.9, &
						-9999.9, -9999.9, -9999.9, -9999.9, -9999.9, -9999.9, -9999.9, -9999.9
				END IF
			END IF
		END DO
	CLOSE(10)
	! ENDTAG: P12
	
	! TAG: P12.1
	! Copy main results file to local root for protocol gathering
	WRITE(sCommand, "('cp ',a,1x,a,'/DiaData.csv')") TRIM(sDiagnosticFile), TRIM(sDataPath)
	CALL SYSTEM(sCommand)
	! ENDTAG: P12.1
	
	! TAG: P13
	! At this point processing has completed successfully. If also last
	! data average in hour, start program to dispatch data to final destinations.
	!CALL UnpackTime(iMaxTimeStamp + iAveragingTime, iMaxYear, iMaxMonth, iMaxDay, iMaxHour, iMaxMinute, iMaxSecond)
	!WRITE(sCommand, "(a,' ',a,' ',a,' ',a,' ',a,' ""',i4.4,2('-',i2.2),' ',i2.2,2(':',i2.2),'""')") &
	!	"/root/bin/preparer.py", &
	!	"/root/cfg/pre.cfg", &
	!	"/root/bin/calcstate.txt", &
	!	"/mnt/ramdisk", &
	!	"/root/tmpdata", &
	!	iYear, iMonth, iDay, iHour, iMinute, iSecond
	!CALL SYSTEM(sCommand)
	!iBlockLimit = 3600 / iAveragingTime
	!IF(iMaxBlock == iBlockLimit) THEN
	!	WRITE(sCommand, "('/root/bin/archive',3(1x,a))") &
	!		TRIM(sInputFile), &
	!		TRIM(sProcessedFile), &
	!		TRIM(sDiagnosticFile)
	!	CALL SYSTEM(sCommand)
	!END IF
	! ENDTAG: P13
	
	! Leave
	CLOSE(101)
	
CONTAINS
	
	FUNCTION ReadInputFile(iLUN, sInputFile, ivTime, rvU, rvV, rvW, rvT) RESULT(iRetCode)
	
		! Routine arguments
		INTEGER, INTENT(IN)								:: iLUN
		CHARACTER(LEN=*), INTENT(IN)					:: sInputFile
		INTEGER, DIMENSION(:), ALLOCATABLE, INTENT(OUT)	:: ivTime
		REAL, DIMENSION(:), ALLOCATABLE, INTENT(OUT)	:: rvU
		REAL, DIMENSION(:), ALLOCATABLE, INTENT(OUT)	:: rvV
		REAL, DIMENSION(:), ALLOCATABLE, INTENT(OUT)	:: rvW
		REAL, DIMENSION(:), ALLOCATABLE, INTENT(OUT)	:: rvT
		INTEGER											:: iRetCode
		
		! Locals
		INTEGER		:: iErrCode
		INTEGER		:: iNumData
		INTEGER		:: iData
		INTEGER(2)	:: iTimeStamp, iU, iV, iW, iT
		
		! Assume success (will falsify on failure)
		iRetCode = 0
		
		! Count how many data are available, and reserve workspace based on this information
		OPEN(iLUN, FILE=sInputFile, STATUS='OLD', ACTION='READ', ACCESS='STREAM', IOSTAT=iErrCode)
		IF(iErrCode /= 0) THEN
			iRetCode = 1
			CLOSE(iLUN)
			RETURN
		END IF
		iNumData = 0
		DO
			
			! Get data in binary form
			READ(10, IOSTAT=iErrCode) iTimeStamp, iV, iU, iW, iT
			IF(iErrCode /= 0) EXIT
			
			! Retain data record pertaining to sonic quadruples only
			IF(iTimeStamp > 3600 .OR. iTimeStamp < 0) CYCLE
			iNumData = iNumData + 1
			
		END DO
		IF(iNumData <= 0) THEN
			iRetCode = 2
			CLOSE(iLUN)
			RETURN
		END IF
		ALLOCATE(ivTime(iNumData), rvU(iNumData), rvV(iNumData), rvW(iNumData), rvT(iNumData))
		REWIND(iLUN)
		
		! Perform actual data read
		iData = 0
		DO
			
			! Get data in binary form
			READ(10, IOSTAT=iErrCode) iTimeStamp, iU, iV, iW, iT
			IF(iErrCode /= 0) EXIT
			
			! Retain data record pertaining to sonic quadruples only
			IF(iTimeStamp > 3600 .OR. iTimeStamp < 0) CYCLE
			iData = iData + 1
			ivTime(iData) = iTimeStamp
			IF(iU > -9990 .AND. iV > -9990 .AND. iW > -9990 .AND. iT > -9990) THEN
				rvU(iData) = iU / 100.
				rvV(iData) = iV / 100.
				rvW(iData) = iW / 100.
				rvT(iData) = iT / 100.
			ELSE
				rvU(iData) = -9999.9
				rvV(iData) = -9999.9
				rvW(iData) = -9999.9
				rvT(iData) = -9999.9
			END IF
			
		END DO
		CLOSE(iLUN)
		
	END FUNCTION ReadInputFile

END PROGRAM eddy_cov

