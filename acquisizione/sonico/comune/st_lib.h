/*

	st_lib - Library containing various utility functions, coded in C.

	Warning: This code is *intentionally* not compatible with C++

	Copyright 2012 by Servizi Territorio srl

*/

#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <syslog.h>
#include <termios.h>
#include <time.h>
#include <sys/resource.h>
#include <sys/stat.h>

#define NUM_DATA 5
#define DATA_SET               "/mnt/ramdisk"
#define DATA_PROCESSING_EXEC   "/home/standard/bin/eddy_cov"
#define DATA_PROCESSING_2D_EXEC "/home/standard/bin/proc2d"
#define DATA_PROCESSING_CONFIG "/home/standard/bin/eddy_cov.nml"
#define DATA_PROCESSING_2D_CONFIG "/home/standard/bin/proc2d.nml"
#define DATA_PROCESSING_REPORT "/mnt/ramdisk/eddy_cov.report"
#define DATA_PROCESSING_2D_REPORT "/mnt/ramdisk/proc2d.report"
#define LOCK_FILE              "/var/run/usa_acq.pid"
#define LOCK_FILE_2D           "/var/run/usa_2d.pid"
#define CMD_INPUT              "/mnt/ramdisk/cmd_server"

// Process management
void daemonize(const char *progName);
void startconsole(const char *progName);
int  isUniqueInstance(const char* sLockFile);

// RS-232 support
int connect(const char* sPortName, const speed_t tSpeed);
void disconnect(int port);
int send(const int port, const char* sLine);
int receive(const int port, const int iMaxChars, const char cLineTerminator, char* sLine);

// String support
int readValue(const char* buffer, const int start, const int nchar);

// USA1, uSonic-3 and uSonic-2 specific
int readDataLine(const short int iTimeStamp, const char* buffer, short int ivData[], const int debug);
int readDataLine3D(const short int iTimeStamp, const char* buffer, short int ivData[], const int debug);
int readDataLine2D(const short int iTimeStamp, const char* buffer, short int ivData[], const int debug);
void dataProcessing(const char* sExec, const char* sProcName, const char* sIniFile, const char* sCurRaw, struct tm *ptTime, const int iMinutes, const int iFuse);
void dataProcessing2D(const char* sExec, const char* sProcName, const char* sCurRaw, struct tm *ptTime, const int iMinutes, const int iFuse);

// Data files and directories support
void openDataFile(FILE* *f, const char* basePath, const int year, const int month, const int day, const int hour);
void openDataFile2D(FILE* *f, const char* basePath, const int year, const int month, const int day, const int hour);

// Timing support
double nowRelative(void);
int nowAbsolute(int iFuse, int* iEpoch, int* iYear, int* iMonth, int* iDay, int* iHour, int* iMinute, int* iSecond);
int isNewAbsoluteTimeStep(int iFuse, int* iOldEpoch, const int iDeltaSeconds);

// USB memory stick support
int checkUsbMemory(const char* sUsbStickMountRoot);

// Circular buffer
void addCircular(
	int iNumData,
	int* iPosLast,
	double* hiResTimeStamp,
	short int* u, short int* v, short int* w, short int* t,
	double newTimeStamp,
	short int newU, short int newV, short int newW, short int newT
);
int getCircular(
	int iNumData,
	int iPosLast,
	double* hiResTimeStamp,
	short int* u, short int* v, short int* w, short int* t,
	double* ordTimeStamp,
	short int* ordU, short int* ordV, short int* ordW, short int* ordT
);
int dumpQuadruple(char* fileName, int iNumData, double* ordTimeStamp, short int* ordU, short int* ordV, short int* ordW, short int* ordT);
int dumpQuadrupleAvgs(
	char* fileName,
	int iNumData,
	double z,
	double* ordTimeStamp, short int* ordU, short int* ordV, short int* ordW, short int* ordT,	// Time stamps may be in any order
	double now,
	size_t iNumAvgs,		// Must be > 0
	double* avgDepth		// Must be in increasing order, with iNumAvgs components
);

//NanoPart and NanoWhere support

void getRawData(
	int iNumData,
	int iSampleSize,
	int iPosLast,
	short int* u, short int* v, short int* w, short int* t,
	short int* smpU, short int* smpV, short int* smpW, short int* smpT
);

void initializeSampling(void);

void getSample(
	int iNumData,
	int iNumDataForNanoPart,
	int iSampleSize,
	int iPosLast,
	short int* u, short int* v, short int* w,
	double* smpU, double* smpV, double* smpW
);

void generateParticle(
	int iNumParticles,
	int iNumSources,
	int* iPosLast,
	double* sourceE,
	double* sourceN,
	double* sourceH,
	double* sourceMass,
	int numParticlesPerStep,
	double* x, double* y, double* z, double* m,
	short int* isValid
);

void generateFootprintParticle(
	int iNumParticles,
	int* iPosLast,
	double initialAltitude,
	double* x, double* y, double* z,
	short int* hasReachedGround
);

void moveParticles(
	int iNumParticles,
	double  sonicFrequency,
	double* x, double* y, double* z,
	short int* isValid,
	double* smpU, double* smpV, double* smpW
);

void moveFootprintParticles(
	int iNumParticles,
	double  sonicFrequency,
	double* x, double* y, double* z, short int* hasReachedGround,
	double* smpU, double* smpV, double* smpW,
	int iNumHits,
	int* iHitPosLast,
	double newTimeStamp,
	double* timeStampHit, double* xHit, double* yHit
);

void dumpParticles(
	char* sFileName,
	int iNumParticles,
	double* x, double* y, double* z,
	short int* isValid
);

void dumpFootprint(
	char* sFileName,
	int iNumHits,
	int* iHitPosLast,
	double currentTimeStamp,
	double deltaTime,
	double* timeStampHit, double* xHit, double* yHit
);
