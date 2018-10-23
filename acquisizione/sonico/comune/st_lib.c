/*

	st_lib - Library containing various utility functions, coded in plain C.

	Copyright 2012 by Servizi Territorio srl
	                  All rights reserved
	
	By: Mauri Favaron (who says "Sorry so sloppy!"; that's obvious anyway: things exist just to be made better)

*/

#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <syslog.h>
#include <termios.h>
#include <math.h>
#include <time.h>
#include <ctype.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <sys/types.h>

#include "st_lib.h"

// Steering constants

#define MAX_CHARLEN 64

/******************
* Process support *
******************/

// Start a program as "daemon", by automatically enforcing all good-behavior
// conventions all UNIX daemons should have.
//
// Original code from
//
//		W.R. Stevens, S.A. Rago,
//		"Advanced Programming in the UNIX Environment", 2nd edition,
//		Pearson, 2008
//
void daemonize(const char *progName) {

	int					i, fd0, fd1, fd2;
	pid_t				pid;
	struct rlimit		rl;
	struct sigaction	sa;
	
	// %TAG: M2.1
	// Clear file creation mask
	umask(0);
	// %ENDTAG: M2.1
	
	// %TAG: M2.2
	// Get max number of file descriptors
	if(getrlimit(RLIMIT_NOFILE, &rl) < 0) exit(1);
	// %ENDTAG: M2.2
	
	// %TAG: M2.3
	// Become a session leader to lose controlling TTY
	if((pid = fork()) < 0) exit(2);	// No resources to perform the fork
	else if(pid != 0) exit(0);		// Parent process
	setsid();
	// %ENDTAG: M2.3
	
	// %TAG: M2.4
	// Ensure future opens will not allocate controlling TTYs
	sa.sa_handler = SIG_IGN;
	sigemptyset( &sa.sa_mask );
	sa.sa_flags = 0;
	if( sigaction(SIGHUP, &sa, NULL) < 0 ) exit(3);
	if( (pid = fork()) < 0 ) exit(4);
	else if(pid != 0) exit(0);
	// %ENDTAG: M2.4
	
	// %TAG: M2.5
	// Change file system to root
	if( chdir("/") < 0 ) exit(5);
	// %ENDTAG: M2.5
	
	// %TAG: M2.6
	// Close all open file descriptors
	if( rl.rlim_max == RLIM_INFINITY ) rl.rlim_max = 1024;
	for(i=0; i<rl.rlim_max; i++) close(i);
	// %ENDTAG: M2.6
	
	// %TAG: M2.7
	// Attach file descriptora 0, 1 and 2 to /dev/null
	fd0 = open("/dev/null", O_RDWR);
	fd1 = dup(0);
	fd2 = dup(0);
	// %ENDTAG: M2.7
	
	// %TAG: M2.8
	// Initialize the log file
	openlog(progName, LOG_CONS, LOG_DAEMON);
	if( fd0 != 0 || fd1 != 1 || fd2 != 2 ) {
		syslog( LOG_ERR, "ST_LIB(PROC) : Unexpected file descriptors %d %d %d", fd0, fd1, fd2 );
		exit(1);
	}
	// %ENDTAG: M2.8

}


// Start a program as a normal console application, but with some respect
// for UNIX good behavior rules for processes.
void startconsole(const char *progName) {

	int					i, fd0, fd1, fd2;
	pid_t				pid;
	struct rlimit		rl;
	struct sigaction	sa;
	
	// %TAG: M2.1
	// Clear file creation mask
	umask(0);
	// %ENDTAG: M2.1
	
	// %TAG: M2.2
	// Get max number of file descriptors
	if(getrlimit(RLIMIT_NOFILE, &rl) < 0) exit(1);
	// %ENDTAG: M2.2
	
	// %TAG: M2.4
	// Ensure future opens will not allocate controlling TTYs
	sa.sa_handler = SIG_IGN;
	sigemptyset( &sa.sa_mask );
	sa.sa_flags = 0;
	if( sigaction(SIGHUP, &sa, NULL) < 0 ) exit(3);
	// %ENDTAG: M2.4
	
	// %TAG: M2.5
	// Change file system to root
	if( chdir("/") < 0 ) exit(5);
	// %ENDTAG: M2.5
	
	// %TAG: M2.8
	// Initialize the log file
	openlog(progName, LOG_CONS, LOG_DAEMON);
	// %ENDTAG: M2.8

}


// Start data processing task, whose name is in "sExec", on data in subdirs of "sDirRaw" data directory, starting on "ptTime", with length "iMinutes"
void dataProcessing(const char* sExec, const char* sProcName, const char* sIniFile, const char* sCurRaw, struct tm *ptTime, const int iMinutes, const int iFuse) {

	char cvDateTime[32];
	char cvMinutes[5];
	char cvFuse[5];
	pid_t iPID;
	
	// If executable name is non empty, start it
	sprintf(cvDateTime,"%4.4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d",ptTime->tm_year+1900,ptTime->tm_mon+1,ptTime->tm_mday,ptTime->tm_hour,ptTime->tm_min,ptTime->tm_sec);
	sprintf(cvMinutes, "%d", iMinutes);
	sprintf(cvFuse, "%d", iFuse);
	syslog(LOG_ERR, "Proc: %s", cvDateTime);
	FILE *fReport = fopen(DATA_PROCESSING_REPORT, "w");
	fprintf(fReport, "Nominal activation time: %s\n", cvDateTime);
	fprintf(fReport, "Raw data directory:      %s\n", sCurRaw);
	fprintf(fReport, "Averaging time:          %s\n", cvMinutes);
	fprintf(fReport, "Fuse:                    %s\n", cvFuse);
	fclose(fReport);
	iPID = fork();
	if(iPID == 0) {
		// This is the child: execute the processing program
		int iRetCode = execl(
			sExec,
			sProcName,
			sIniFile,
			sCurRaw,
			cvDateTime,
			cvMinutes,
			cvFuse,
			NULL
		);
		exit(0); // Allow the child process to terminate, after which the
				 // scheduler makes it a "zombie". Zombies need to be removed
				 // by another process.
	}
		
}


void dataProcessing2D(const char* sExec, const char* sProcName, const char* sCurRaw, struct tm *ptTime, const int iMinutes, const int iFuse) {

	char cvDateTime[32];
	char cvMinutes[5];
	char cvFuse[5];
	pid_t iPID;
	
	// If executable name is non empty, start it
	sprintf(cvDateTime,"%4.4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d",ptTime->tm_year+1900,ptTime->tm_mon+1,ptTime->tm_mday,ptTime->tm_hour,ptTime->tm_min,ptTime->tm_sec);
	sprintf(cvMinutes, "%d", iMinutes);
	sprintf(cvFuse, "%d", iFuse);
	syslog(LOG_ERR, "Proc: %s", cvDateTime);
	FILE *fReport = fopen(DATA_PROCESSING_2D_REPORT, "w");
	fprintf(fReport, "Executable:              %s\n", sExec);
	fprintf(fReport, "Process name:            %s\n", sProcName);
	fprintf(fReport, "Raw data file:           %s\n", sCurRaw);
	fprintf(fReport, "Nominal activation time: %s\n", cvDateTime);
	fprintf(fReport, "Raw data directory:      %s\n", sCurRaw);
	fprintf(fReport, "Averaging time:          %s\n", cvMinutes);
	fprintf(fReport, "Fuse:                    %s\n", cvFuse);
	fclose(fReport);
	iPID = fork();
	if(iPID == 0) {
		// This is the child: execute the processing program
		int iRetCode = execl(
			sExec,
			sProcName,
			sCurRaw,
			cvDateTime,
			cvMinutes,
			cvFuse,
			NULL
		);
		exit(0); // Allow the child process to terminate, after which the
				 // scheduler makes it a "zombie". Zombies need to be removed
				 // by another process.
	}
		
}


// Check this process current instance is not trying to start if another
// is running, by looking at its lock file
int isUniqueInstance(const char* sLockFile) {
	
	// Check whether lock file exists by opening it as "old" and making
	// sure the attempt fails
	int iFile = open(sLockFile, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
	if(iFile < 0) {
		return 0;
	}
	else {
		
		// Attempt acquiring a lock on file: this operation succeeds fails if
		// the file is locked by another instance
		struct flock fl;
		fl.l_type   = F_WRLCK;
		fl.l_start  = 0;
		fl.l_whence = SEEK_SET;
		fl.l_len    = 0;
		int iLock = fcntl(iFile, F_SETLK, &fl);
		if(iLock < 0)
			if(errno == EACCES || errno == EAGAIN) {
				close(iFile);
				return 0;
			}
		
		// Post: File has been opened and is not locked: so "I" may
		//       write and lock it. To make things clearer to
		// systems programmers, the PID of creating process is
		// printed to file.
		ftruncate(iFile, 0);
		char buf[16];
		sprintf(buf, "%ld\n", (long)getpid());
		write(iFile, buf, strlen(buf)+1);
		return(-1);
		
	}
}


/**********************
* Serial Port support *
**********************/

#define RS232_MINCHAR 0
#define RS232_TIMEOUT 50

// Connect ("open") a serial port under Linux, in a way allowing sonic
// anemmeters and similar instruments to be actually logged.
// (The correct settings have been discovered through trial-and-error,
// on my "personal" Netus G20 machine; I advise you: change any byte,
// and chances are good nothing works).
int connect(const char* sPortName, const speed_t tSpeed) {

	int     port, speed, retCode;
	speed_t baudRate;
	struct termios termAttr;
	
	// %TAG: M5.1
	// Connect the port as a UNIX file, in blocking mode.
	errno = 0;
	if((port = open(sPortName, O_RDWR|O_NOCTTY)) < 0) {
		syslog( LOG_ERR, "ST_LIB(RS232) : Failure opening port %s", sPortName);
		return(-1);
	}
	// %ENDTAG: M5.1
	
	// %TAG: M5.2
	// Check the file corresponds to a terminal.
	errno = 0;
	if(!isatty(port)) {
		syslog( LOG_ERR, "ST_LIB(RS232) : Port %s is not a TTY", sPortName);
		return(-2);
	}
	// %ENDTAG: M5.2
	
	// %TAG: M5.3
	// c_cflag
	// Enable receiver and force 8 data bits
	tcgetattr(port, &termAttr);
	termAttr.c_cflag |= CREAD;
	termAttr.c_cflag |= CS8;
	// %ENDTAG: M5.3
	
	// %TAG: M5.4
	// c_iflag
	// Ignore framing errors and parity errors.
	termAttr.c_iflag |= IGNPAR;
	// %ENDTAG: M5.4
	
	// %TAG: M5.5
	// c_lflag
	// DISABLE canonical mode.
	// Disables the special characters EOF, EOL, EOL2,
	// ERASE, KILL, LNEXT, REPRINT, STATUS, and WERASE, and buffers by lines.
	termAttr.c_lflag &= ~(ICANON);
	termAttr.c_lflag &= ~(ECHO);
	termAttr.c_lflag &= ~(ECHOE);
	termAttr.c_lflag &= ~(ISIG);
	// %ENDTAG: M5.5
	
	// %TAG: M5.6
	// Minimum number of characters for non-canonical read
	// (if zero, use timeout; set to 1 to use inter-byte timeout).
	termAttr.c_cc[VMIN]=RS232_MINCHAR;
	// %ENDTAG: M5.6
	
	// %TAG: M5.7
	// Timeout in deciseconds for non-canonical read.
	termAttr.c_cc[VTIME]=RS232_TIMEOUT;
	// %ENDTAG: M5.7
 	
	// %TAG: M5.8
 	// Set port speed
	cfsetispeed(&termAttr, tSpeed);
	cfsetospeed(&termAttr, tSpeed);
	// %ENDTAG: M5.8
	
	// %TAG: M5.9
	// Retrieve port speed and save it to port state, for future reference
	speed = -1;
	baudRate = cfgetispeed(&termAttr);
	switch (baudRate) {
		case B0:      speed = 0;     break;
		case B50:     speed = 50;    break;
		case B110:    speed = 110;   break;
		case B134:    speed = 134;   break;
		case B150:    speed = 150;   break;
		case B200:    speed = 200;   break;
		case B300:    speed = 300;   break;
		case B600:    speed = 600;   break;
		case B1200:   speed = 1200;  break;
		case B1800:   speed = 1800;  break;
		case B2400:   speed = 2400;  break;
		case B4800:   speed = 4800;  break;
		case B9600:   speed = 9600;  break;
		case B19200:  speed = 19200; break;
		case B38400:  speed = 38400; break;
	}
	// %ENDTAG: M5.9
	
	// %TAG: M5.10
	// Commit the port state
	errno = 0;
	retCode = tcsetattr(port, TCSANOW, &termAttr);
	if(retCode != 0) {
		syslog( LOG_ERR, "ST_LIB(RS232) : Attempt to commit state for port %s failed", sPortName);
		return(-3);
	}
	// %ENDTAG: M5.10
	
	// Leave
	return(port);
	
}


// Whoops! Only a wrapper. I just love coupling names, and "connect" didn't match
// well with "close".
void disconnect(int port) {
	close(port);
}


// Send a string on serial line as it is (line terminating character is
// assumed to be embedded in string).
int send(const int port, const char* sLine) {

	char    ch[1];
	ssize_t iBytes     = 0;
	int     iErrorCode = 0;
	unsigned int i;
	
	for(i=0; i<strlen(sLine); i++) {
		ch[0] = sLine[i];
		iBytes = write(port, ch, 1);
		if(iBytes < 1) {
			iErrorCode = errno;
			break;
		}
	}
	
	return(iErrorCode);
	
}


#define MAX_BUFSIZE 256
#define BLK_SIZE 	 16

#define RS232_STAT_EMPTY   0
#define RS232_STAT_NORMAL  1
#define RS232_STAT_TIMEOUT 2

// Get a line from the serial port
int receive(const int port, const int iMaxChars, const char cLineTerminator, char* sLine) {

	// %TAG: M10.2.1
	// Receive data into buffer (the flags 'bStringOK' and 'bStringComplete' are
	// not in the moment used, but might be in future).
	char rxBuffer[BLK_SIZE];
	int i = 0;
	int iSize;
	int iStatus = RS232_STAT_EMPTY;
	int iRetCode;
	do {
		// Wait until a character arrives
		iSize = read(port,&rxBuffer,1);
		if(iSize == 1) {
			sLine[i++] = rxBuffer[0];
			if(i >= iMaxChars-2) break;
		}
		else {
			// No char received: Timeout event
			iStatus = RS232_STAT_TIMEOUT;
			break;
		}
	} while(rxBuffer[0] != cLineTerminator);
	sLine[i] = '\0';
	if(iStatus != RS232_STAT_TIMEOUT && i>0) iStatus = RS232_STAT_NORMAL;
	// %ENDTAG: M10.2.1
	
	// %TAG: M10.2.2
	// Normalize buffer, stripping all line terminators, if any. In this processing,
	// the plain C convention of using character '\0' as string terminator is relied on.
	for(i=0; i<strlen(sLine); i++) {
		if(sLine[i] == '\x0d' || sLine[i] == '\x0a') sLine[i] = '\0';
	}
	// %ENDTAG: M10.2.2
	
	// %TAG: M10.2.3
	// Leave
	switch(iStatus) {
	case RS232_STAT_EMPTY:
		iRetCode = 0;
		break;
	case RS232_STAT_TIMEOUT:
		iRetCode = -1;
		break;
	case RS232_STAT_NORMAL:
		iRetCode = strlen(sLine);
		break;
	default:
		iRetCode = -2;
		break;
	}
	// %ENDTAG: M10.2.3
	
	// Leave
	return iRetCode;

}

/*****************
* String support *
*****************/

int readValue(const char* buffer, const int start, const int nchar) {

	char substring[MAX_CHARLEN];
	int i;
	int iNumDigits = 0;
	int iNumSpaces = 0;
	int iNumMinus = 0;
	int value;
	
	// Get field, as it is
	for(i=start; i<start+nchar; i++) {
		substring[i-start] = buffer[i];
		if(isdigit(buffer[i])) iNumDigits++;
		if(isspace(buffer[i])) iNumSpaces++;
		if(buffer[i] == '-')   iNumMinus++;
	}
	substring[nchar] = '\0';
	
	// Try converting it to integer
	if(iNumDigits <= 0 || iNumMinus >= 2 || iNumDigits+iNumSpaces+iNumMinus != nchar) {
		value = -9999;
	}
	else value = atoi(substring);
	
	// Leave
	return(value);
	
}

/****************
* USA1 specific *
****************/

int readDataLine(const short int iTimeStamp, const char* buffer, short int ivData[], const int debug) {

	// Declarations
	int iRecordType = 0;
	short int Val1, Val2, Val3, Val4;

	// Parse data lines
	// %TAG: M10.2.4
	if(strlen(buffer) == 2 && (buffer[0] == 'M' || buffer[0] == 'H')) {
			// UVWT quadruple
			Val1 = -9999;
			Val2 = -9999;
			Val3 = -9999;
			Val4 = -9999;
			if(debug) printf("T:%5d D0:%5d,%5d,%5d,%5d\n", iTimeStamp, Val1, Val2, Val3, Val4);
			iRecordType = 1;
	}
	if(strlen(buffer) == 41) {
	// %ENDTAG: M10.2.4
		
		// %TAG: M10.2.5
		if(buffer[2] == 'x') {
			
			// UVWT quadruple in USA-1 convention (U and V exchanged respect geographical convention)
			Val2 = readValue(buffer, 5, 6);
			Val1 = readValue(buffer, 15, 6);
			Val3 = readValue(buffer, 25, 6);
			Val4 = readValue(buffer, 35, 6);
			if(debug) printf("T:%5d D0:%5d,%5d,%5d,%5d\n", iTimeStamp, Val1, Val2, Val3, Val4);
			iRecordType = 1;
			
		}
		// %ENDTAG: M10.2.5
				
		// %TAG: M10.2.6
		if((buffer[2] == 'a' && buffer[3] == '0') || (buffer[2] == 'e' && buffer[3] == '1')) {
			
			// Analog quadruples, 1st block
			Val1 = readValue(buffer, 5, 6) & 0x0000ffff;
			Val2 = readValue(buffer, 15, 6) & 0x0000ffff;
			Val3 = readValue(buffer, 25, 6) & 0x0000ffff;
			Val4 = readValue(buffer, 35, 6) & 0x0000ffff;
			if(debug) printf("T:%5d A1:%5d,%5d,%5d,%5d\n", iTimeStamp, Val1, Val2, Val3, Val4);
			iRecordType = 2;
			
		}
		// %ENDTAG: M10.2.6
		
		// %TAG: M10.2.7
		if((buffer[2] == 'a' && buffer[3] == '4') || (buffer[2] == 'e' && buffer[3] == '5')) {
	
			// Analog quadruples, 2nd block
			Val1 = readValue(buffer, 5, 6) & 0x0000ffff;
			Val2 = readValue(buffer, 15, 6) & 0x0000ffff;
			Val3 = readValue(buffer, 25, 6) & 0x0000ffff;
			Val4 = readValue(buffer, 35, 6) & 0x0000ffff;
			if(debug) printf("T:%5d A2:%5d,%5d,%5d,%5d\n", iTimeStamp, Val1, Val2, Val3, Val4);
			iRecordType = 3;
			
		}
		// %ENDTAG: M10.2.7
		
		// %TAG: M10.2.8
		// Prepare data for writing
		ivData[0] = iTimeStamp + (iRecordType-1) * 5000;
		ivData[1] = Val1;
		ivData[2] = Val2;
		ivData[3] = Val3;
		ivData[4] = Val4;
		// %ENDTAG: M10.2.8
		
		// Leave
		return(iRecordType);
		
	}

}

/********************
* uSonic-3 specific *
********************/

int readDataLine3D(const short int iTimeStamp, const char* buffer, short int ivData[], const int debug) {

	// Declarations
	int iRecordType = 0;
	short int Val1, Val2, Val3, Val4;

	// Parse data lines
	// %TAG: M10.2.4
	if(strlen(buffer) == 2 && (buffer[0] == 'M' || buffer[0] == 'H')) {
			// UVWT quadruple
			Val1 = -9999;
			Val2 = -9999;
			Val3 = -9999;
			Val4 = -9999;
			if(debug) printf("T:%5d D0:%5d,%5d,%5d,%5d\n", iTimeStamp, Val1, Val2, Val3, Val4);
			iRecordType = 1;
	}
	if(strlen(buffer) == 41) {
	// %ENDTAG: M10.2.4
		
		// %TAG: M10.2.5
		if(buffer[2] == 'x') {
			
			// UVWT quadruple
			Val1 = readValue(buffer, 5, 6);
			Val2 = readValue(buffer, 15, 6);
			Val3 = readValue(buffer, 25, 6);
			Val4 = readValue(buffer, 35, 6);
			if(debug) printf("T:%5d D0:%5d,%5d,%5d,%5d\n", iTimeStamp, Val1, Val2, Val3, Val4);
			iRecordType = 1;
			
		}
		// %ENDTAG: M10.2.5
				
		// %TAG: M10.2.6
		if((buffer[2] == 'a' && buffer[3] == '0') || (buffer[2] == 'e' && buffer[3] == '1')) {
			
			// Analog quadruples, 1st block
			Val1 = readValue(buffer, 5, 6) & 0x0000ffff;
			Val2 = readValue(buffer, 15, 6) & 0x0000ffff;
			Val3 = readValue(buffer, 25, 6) & 0x0000ffff;
			Val4 = readValue(buffer, 35, 6) & 0x0000ffff;
			if(debug) printf("T:%5d A1:%5d,%5d,%5d,%5d\n", iTimeStamp, Val1, Val2, Val3, Val4);
			iRecordType = 2;
			
		}
		// %ENDTAG: M10.2.6
		
		// %TAG: M10.2.7
		if((buffer[2] == 'a' && buffer[3] == '4') || (buffer[2] == 'e' && buffer[3] == '5')) {
	
			// Analog quadruples, 2nd block
			Val1 = readValue(buffer, 5, 6) & 0x0000ffff;
			Val2 = readValue(buffer, 15, 6) & 0x0000ffff;
			Val3 = readValue(buffer, 25, 6) & 0x0000ffff;
			Val4 = readValue(buffer, 35, 6) & 0x0000ffff;
			if(debug) printf("T:%5d A2:%5d,%5d,%5d,%5d\n", iTimeStamp, Val1, Val2, Val3, Val4);
			iRecordType = 3;
			
		}
		// %ENDTAG: M10.2.7
		
		// %TAG: M10.2.8
		// Prepare data for writing
		ivData[0] = iTimeStamp + (iRecordType-1) * 5000;
		ivData[1] = Val1;
		ivData[2] = Val2;
		ivData[3] = Val3;
		ivData[4] = Val4;
		// %ENDTAG: M10.2.8
		
		// Leave
		return(iRecordType);
		
	}

}

/********************
* uSonic 2 specific *
********************/

int readDataLine2D(const short int iTimeStamp, const char* buffer, short int ivData[], const int debug) {

	// Declarations
	short int Val1, Val2, Val3, Val4;
	int iRetCode;
	
	// Assume troubles (will verify on failure)
	Val1 = -9999;
	Val2 = -9999;
	Val3 = -9999;
	Val4 = -9999;
	iRetCode = 1;

	if(strlen(buffer) == 41) {
		
		if(debug) printf("T:%5d Buf:%s\n", iTimeStamp, buffer);

		if(buffer[2] == 'x') {
			
			// UVTQ quadruple
			Val1 = readValue(buffer, 5, 6);
			Val2 = readValue(buffer, 15, 6);
			Val3 = readValue(buffer, 25, 6);
			Val4 = readValue(buffer, 35, 6);
			ivData[0] = iTimeStamp;
			ivData[1] = Val1;
			ivData[2] = Val2;
			ivData[3] = Val3;
			ivData[4] = Val4;
			
			iRetCode = 0;
			
		}

		
		// Leave
		return(iRetCode);
		
	}

}

/***********************
* Directory management *
***********************/

void openDataFile(FILE* *f, const char* basePath, const int year, const int month, const int day, const int hour) {

	char buffer[256];
	int retVal;
	
	sprintf(buffer, "%s/%04d%02d%02d.%02dR", basePath, year, month, day, hour);
	*f = fopen(buffer, "wa");
	// printf("%s\n", buffer);
	
}

void openDataFile2D(FILE* *f, const char* basePath, const int year, const int month, const int day, const int hour) {

	char buffer[256];
	int retVal;
	
	sprintf(buffer, "%s/%04d%02d%02d.%02dS", basePath, year, month, day, hour);
	*f = fopen(buffer, "wa");
	// printf("%s\n", buffer);
	
}

/*********************************
* Time and time stamp management *
*********************************/

double nowRelative(void) {

	struct timespec tTimeStamp;
	long iEpoch;
	char iHundredth;
	double dTimeStamp;
	
	clock_gettime(CLOCK_MONOTONIC, &tTimeStamp);
	iEpoch = tTimeStamp.tv_sec;
	iHundredth = (char)(tTimeStamp.tv_nsec / 10000000l);
	
	dTimeStamp = (double)iEpoch + iHundredth/100.0;
	
	return(dTimeStamp);
	
}


int nowAbsolute(int iFuse, int* iEpoch, int* iYear, int* iMonth, int* iDay, int* iHour, int* iMinute, int* iSecond) {

	time_t tNewTime;
	struct tm *ptTime;
	int iTimeStamp;
	
	time(&tNewTime);
	tNewTime += (time_t)(iFuse * 3600);
	ptTime = gmtime(&tNewTime);
	iTimeStamp = ptTime->tm_min*60 + ptTime->tm_sec;
	
	*iEpoch  = (int)tNewTime;
	*iYear   = ptTime->tm_year + 1900;
	*iMonth  = ptTime->tm_mon + 1;
	*iDay    = ptTime->tm_mday;
	*iHour   = ptTime->tm_hour;
	*iMinute = ptTime->tm_min;
	*iSecond = ptTime->tm_sec;
	
	return(iTimeStamp);
	
}


int isNewAbsoluteTimeStep(int iFuse, int* iOldEpoch, const int iDeltaSeconds) {

	time_t tNewTime;
	int iOldBlock;
	int iNewBlock;
	
	// Compute current time in epoch
	time(&tNewTime);
	tNewTime += (time_t)(iFuse * 3600);
	
	// Check new time to (not) be in the same time step as old time,
	// with the specified time delta
	iOldBlock = (*iOldEpoch / iDeltaSeconds) * iDeltaSeconds;
	iNewBlock = ((int)tNewTime / iDeltaSeconds) * iDeltaSeconds;
	if(iNewBlock != iOldBlock) {
		*iOldEpoch = iNewBlock;
		return(-1);
	}
	else {
		return(0);
	}

}


/*********************************
* USB memory stick related calls *
*********************************/

// Check USB stick mount status and integrity
int checkUsbMemory(const char* sUsbStickMountRoot) {

	int iRetCode = 0;
	struct stat dir_info;
	int result;
	dev_t baseDevID;
	dev_t mountPointDevID;
	
	// Get directory & device info for root filesystem
	result = stat("/", &dir_info);
	if(result != 0) {
		iRetCode = 1;	// Dir & dev info of root can not be queried
		return(iRetCode);
	}
	baseDevID = dir_info.st_dev;
	
	// Get directory & device info for USB stick: if mounted, device ID
	// differs from root's
	result = stat(sUsbStickMountRoot, &dir_info);
	if(result != 0) {
		iRetCode = 2;	// Dir & dev info of supposed USB stick can not be queried
		return(iRetCode);
	}
	mountPointDevID = dir_info.st_dev;
	
	// Check mount status
	if(mountPointDevID == baseDevID) {
		iRetCode = 3;	// Dev IDs of root and USB stick do not differ => Key not mounted
		return(iRetCode);
	}
	
	// Device mounted, check it is not read-only the direct way:
	// try writing a new file, and check it really was created.
	
	// Leave
	return(iRetCode);
	
}

/******************
* Circular buffer *
******************/

void addCircular(
	int iNumData,
	int* iPosLast,
	double* hiResTimeStamp,
	short int* u, short int* v, short int* w, short int* t,
	double newTimeStamp,
	short int newU, short int newV, short int newW, short int newT
) {

	// Set position of next packet, based on last
	int iPosCurrent = (*iPosLast)+1;
	if(iPosCurrent >= iNumData) iPosCurrent = 0;

	hiResTimeStamp[iPosCurrent] = newTimeStamp;
	u[iPosCurrent]              = newU;
	v[iPosCurrent]              = newV;
	w[iPosCurrent]              = newW;
	t[iPosCurrent]              = newT;
	
	*iPosLast = iPosCurrent;
	
}


int getCircular(
	int iNumData,
	int iPosLast,
	double* hiResTimeStamp,
	short int* u, short int* v, short int* w, short int* t,
	double* ordTimeStamp,
	short int* ordU, short int* ordV, short int* ordW, short int* ordT
) {

	// Transfer the information desired
	int i;
	int j = 0;
	for(i=iPosLast; i<iNumData; i++) {
		ordTimeStamp[j] = hiResTimeStamp[i];
		ordU[j] = u[i];
		ordV[j] = v[i];
		ordW[j] = w[i];
		ordT[j] = t[i];
		j++;
	}
	for(i=0; i<iPosLast; i++) {
		ordTimeStamp[j] = hiResTimeStamp[i];
		ordU[j] = u[i];
		ordV[j] = v[i];
		ordW[j] = w[i];
		ordT[j] = t[i];
	}

};


int dumpQuadruple(char* fileName, int iNumData, double* ordTimeStamp, short int* ordU, short int* ordV, short int* ordW, short int* ordT) {

	// Assume success
	int iRetCode = 0;

	// Write data in binary form
	FILE* f = fopen(fileName, "wb");
	if(!f) {
		iRetCode = 1;
		return iRetCode;
	}
	fwrite((void*)&iNumData, sizeof(int), (size_t)1, f);
	fwrite((void*)ordTimeStamp, sizeof(double), (size_t)iNumData, f);
	fwrite((void*)ordU, sizeof(short int), (size_t)iNumData, f);
	fwrite((void*)ordV, sizeof(short int), (size_t)iNumData, f);
	fwrite((void*)ordW, sizeof(short int), (size_t)iNumData, f);
	fwrite((void*)ordT, sizeof(short int), (size_t)iNumData, f);
	fclose(f);

	return iRetCode;

};


void initializeSampling(void) {
	srand(time(NULL));
}


void getRawData(
	int iNumData,
	int iSampleSize,
	int iPosLast,
	short int* u, short int* v, short int* w, short int* t,
	short int* smpU, short int* smpV, short int* smpW, short int* smpT
) {

	// Compute useful values
	int iFirst = iPosLast - iSampleSize + 1;

	// Randomly generate sampling indices
	int i;
	int smpIdx = iFirst;
	for(i=0; i<iSampleSize; i++) {

		// Extract sample data and convert them to m/s on the fly
		smpU[i] = u[smpIdx];
		smpV[i] = v[smpIdx];
		smpW[i] = w[smpIdx];
		smpT[i] = t[smpIdx];
		smpIdx++;

	}

}


void getSample(
	int iNumData,
	int iNumDataForNanoPart,
	int iSampleSize,
	int iPosLast,
	short int* u, short int* v, short int* w,
	double* smpU, double* smpV, double* smpW
) {

	// Compute useful values
	int iFirst = iPosLast - iNumDataForNanoPart + 1;

	// Randomly generate sampling indices
	int i;
	int smpIdx;
	for(i=0; i<iSampleSize; i++) {

		// Get sample index
		smpIdx = rand() % iNumDataForNanoPart;	// Not perfectly uniform, yet standard C; will use something better sooner or later (offline NanoPart uses a more accurate version)
		smpIdx = smpIdx + iFirst;
		if(smpIdx < 0) smpIdx += iNumData;

		// Extract sample data and convert them to m/s on the fly
		smpU[i] = u[smpIdx] * 0.01;
		smpV[i] = v[smpIdx] * 0.01;
		smpW[i] = w[smpIdx] * 0.01;

	}

}


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
) {
	
	int iSrc;
	int iPart;
	for(iSrc = 0; iSrc < iNumSources; iSrc++) {
		for(iPart = 1; iPart < numParticlesPerStep; iPart++) {

			// Set position of next packet, based on last
			int iPosCurrent = (*iPosLast)+1;
			if(iPosCurrent >= iNumParticles) iPosCurrent = 0;

			x[iPosCurrent]              = sourceE[iSrc];
			y[iPosCurrent]              = sourceN[iSrc];
			z[iPosCurrent]              = sourceH[iSrc];
			m[iPosCurrent]              = sourceMass[iSrc];
			
			isValid[iPosCurrent]        = 1;
			*iPosLast = iPosCurrent;
			
		}
	}
	
}


void generateFootprintParticle(
	int iNumParticles,
	int* iPosLast,
	double initialAltitude,
	double* x, double* y, double* z, short int* hasReachedGround
) {

	// Set position of next packet, based on last
	int iPosCurrent = (*iPosLast)+1;
	if(iPosCurrent >= iNumParticles) iPosCurrent = 0;

	x[iPosCurrent]                = 0.0;
	y[iPosCurrent]                = 0.0;
	z[iPosCurrent]                = initialAltitude;
	hasReachedGround[iPosCurrent] = 0;
	
	*iPosLast = iPosCurrent;
	
}


void moveParticles(
	int iNumParticles,
	double  sonicFrequency,
	double* x, double* y, double* z,
	short int* isValid,
	double* smpU, double* smpV, double* smpW
) {

	// Move particles according to sample
	double deltaT = 1.0 / sonicFrequency;
	int iPart;
	for(iPart = 0; iPart < iNumParticles; iPart++) {
		if(isValid[iPart] > 0) {
			x[iPart] += smpU[iPart] * deltaT;
			y[iPart] += smpV[iPart] * deltaT;
			z[iPart] += smpW[iPart] * deltaT;
			if(z[iPart] < 0) z[iPart] = -z[iPart];
		}
	}

}


void moveFootprintParticles(
	int iNumParticles,
	double  sonicFrequency,
	double* x, double* y, double* z, short int* hasReachedGround,
	double* smpU, double* smpV, double* smpW,
	int iNumHits,
	int* iHitPosLast,
	double newTimeStamp,
	double* timeStampHit, double* xHit, double* yHit
) {

	// Move particles according to sample
	double deltaT = 1.0 / sonicFrequency;
	int iPart;
	for(iPart = 0; iPart < iNumParticles; iPart++) {
		if(hasReachedGround[iPart] <= 0) {
			x[iPart] -= smpU[iPart] * deltaT;
			y[iPart] -= smpV[iPart] * deltaT;
			z[iPart] -= smpW[iPart] * deltaT;
			if(z[iPart] < 0) {

				// Record hit
				int iPosCurrent = (*iHitPosLast)+1;
				if(iPosCurrent >= iNumHits) iPosCurrent = 0;

				timeStampHit[iPosCurrent] = newTimeStamp;
				xHit[iPosCurrent]         = x[iPart];
				yHit[iPosCurrent]         = y[iPart];
				
				*iHitPosLast = iPosCurrent;

				// Remember one hit has occurred, to avoid this particle from contributing to footprint again
				hasReachedGround[iPart] = 1;

			}
		}
	}

}


void dumpParticles(
	char* sFileName,
	int iNumParticles,
	double* x, double* y, double* z,
	short int* isValid
) {

	// Connect output file
	FILE* f = fopen(sFileName, "w");
	if(!f) return;

	// Write data
	int i;
	for(i = 0; i < iNumParticles; i++) {
		short int iX, iY, iZ;
		if(isValid[i] > 0) {
			if(fabs(x[i]) < 3276 && fabs(y[i]) < 3276 && fabs(z[i]) < 3276) {
				iX = (short int)(x[i]*10.0);
				iY = (short int)(y[i]*10.0);
				iZ = (short int)(z[i]*10.0);
				fprintf(f, "%d,%d,%d\n", iX, iY, iZ);
			}
		}
	}

	// Leave
	fclose(f);

}


void dumpFootprint(
	char* sFileName,
	int iNumHits,
	int* iHitPosLast,
	double currentTimeStamp,
	double deltaTime,
	double* timeStampHit, double* xHit, double* yHit
) {

	// Compute timeselection limits
	double timeFrom = currentTimeStamp - deltaTime;
	double timeTo   = currentTimeStamp;

	// Compute footprint center, width and eccentricity
	int i;
	int iHits = 0;
	double sumX  = 0.0;
	double sumY  = 0.0;
	double sumXX = 0.0;
	double sumYY = 0.0;
	double avgX;
	double avgY;
	double varX;
	double varY;
	double e;
	double r;
	for(i = 0; i < iNumHits; i++) if(timeFrom < timeStampHit[i] && timeStampHit[i] <= timeTo) {
		iHits++;
		sumX += xHit[i];
		sumY += yHit[i];
		sumXX += xHit[i]*xHit[i];
		sumYY += yHit[i]*yHit[i];
	}
	if(iHits > 0) {
		avgX = sumX / iHits;
		avgY = sumY / iHits;
		varX = sumXX / iHits - avgX*avgX;
		varY = sumYY / iHits - avgY*avgY;
		r    = sqrt(varX + varY);
		if(varX > varY) {
			e = sqrt(1.0 - varY/varX);
		}
		else {
			e = sqrt(1.0 - varX/varY);
		}
	}
	else {
		avgX = -9999.9;
		avgY = -9999.9;
		varX = -9999.9;
		varY = -9999.9;
		r    = -9999.9;
		e    = -9999.9;
	}
	FILE* f = fopen(sFileName, "w");
	if(!f) return;
	fprintf(f,"%f\n", avgX);
	fprintf(f,"%f\n", avgY);
	fprintf(f,"%f\n", r);
	fprintf(f,"%f\n", e);
	fclose(f);
}


#define MAX_AVGS 16

int dumpQuadrupleAvgs(
	char* fileName,
	int iNumData,
	double z,				// Station altitude above MSL (m)
	double* ordTimeStamp, short int* ordU, short int* ordV, short int* ordW, short int* ordT,	// Time stamps may be in any order
	double now,
	size_t iNumAvgs,		// Must be > 0
	double* avgDepth		// Must be in increasing order, with iNumAvgs components
) {

	// Assume success
	int iRetCode = 0;
	
	// Check number of desired averaging times matches maximum value
	if(iNumAvgs > MAX_AVGS) {
		iRetCode = 1;
		return iRetCode;
	}
	int numSum[MAX_AVGS];
	double sumU[MAX_AVGS], sumV[MAX_AVGS], sumW[MAX_AVGS], sumT[MAX_AVGS];
	double sumUU[MAX_AVGS], sumVV[MAX_AVGS], sumWW[MAX_AVGS], sumTT[MAX_AVGS];
	double sumUV[MAX_AVGS], sumUW[MAX_AVGS], sumVW[MAX_AVGS];
	double sumUT[MAX_AVGS], sumVT[MAX_AVGS], sumWT[MAX_AVGS];
	double sumVel[MAX_AVGS], sumVel2[MAX_AVGS];
	double fromTime[MAX_AVGS];
	
	// Main loop: form partial sums based on quadruples time stamps
	int curAvg;
	for(curAvg=0; curAvg<iNumAvgs; curAvg++) {
		numSum[curAvg] = 0;
		sumU[curAvg]   = 0.;
		sumV[curAvg]   = 0.;
		sumW[curAvg]   = 0.;
		sumT[curAvg]   = 0.;
		sumUU[curAvg]  = 0.;
		sumVV[curAvg]  = 0.;
		sumWW[curAvg]  = 0.;
		sumTT[curAvg]  = 0.;
		sumUV[curAvg]  = 0.;
		sumUW[curAvg]  = 0.;
		sumVW[curAvg]  = 0.;
		sumUT[curAvg]  = 0.;
		sumVT[curAvg]  = 0.;
		sumWT[curAvg]  = 0.;
		sumVel[curAvg] = 0.;
		sumVel2[curAvg] = 0.;
		fromTime[curAvg] = now - avgDepth[curAvg];
	}
	double U, V, W, T;
	int i;
	for(i=0; i<iNumData; i++) {
		for(curAvg=0; curAvg<iNumAvgs; curAvg++) {
			if(fromTime[curAvg] < ordTimeStamp[i] && ordTimeStamp[i] <= now) {
				numSum[curAvg]++;
				U = ordU[i]/100.0;
				V = ordV[i]/100.0;
				W = ordW[i]/100.0;
				T = ordT[i]/100.0;
				sumU[curAvg]  += U;
				sumV[curAvg]  += V;
				sumW[curAvg]  += W;
				sumT[curAvg]  += T;
				sumUU[curAvg] += U*U;
				sumVV[curAvg] += V*V;
				sumWW[curAvg] += W*W;
				sumTT[curAvg] += T*T;
				sumUV[curAvg] += U*V;
				sumUW[curAvg] += U*W;
				sumVW[curAvg] += V*W;
				sumUT[curAvg] += U*T;
				sumVT[curAvg] += V*T;
				sumWT[curAvg] += W*T;
				sumVel2[curAvg] += U*U + V*V;
				sumVel[curAvg]  += sqrt(U*U + V*V);
				break;
			}
		}
	}
	
	// Convert from partial to total sums
	for(curAvg=1; curAvg<iNumAvgs; curAvg++) {
		numSum[curAvg] += numSum[curAvg-1];
		sumU[curAvg]   += sumU[curAvg-1];
		sumV[curAvg]   += sumV[curAvg-1];
		sumW[curAvg]   += sumW[curAvg-1];
		sumT[curAvg]   += sumT[curAvg-1];
		sumUU[curAvg]  += sumUU[curAvg-1];
		sumVV[curAvg]  += sumVV[curAvg-1];
		sumWW[curAvg]  += sumWW[curAvg-1];
		sumTT[curAvg]  += sumTT[curAvg-1];
		sumUV[curAvg]  += sumUV[curAvg-1];
		sumUW[curAvg]  += sumUW[curAvg-1];
		sumVW[curAvg]  += sumVW[curAvg-1];
		sumUT[curAvg]  += sumUT[curAvg-1];
		sumVT[curAvg]  += sumVT[curAvg-1];
		sumWT[curAvg]  += sumWT[curAvg-1];
		sumVel[curAvg] += sumVel[curAvg-1];
		sumVel2[curAvg] += sumVel2[curAvg-1];
	}
	
	// Perform 2 axis rotation and other statistical calculations; write them
	double vel, dir, temp, scalarVel, vel2, velStd, uAvg, vAvg, wAvg, tAvg;
	double uStd, vStd, wStd, tStd;
	double uvCov, uwCov, vwCov;
	double utCov, vtCov, wtCov;
	double uStar, H0, lm1;
	double rPhi;
	FILE* f = fopen(fileName, "w");
	if(!f) {
		iRetCode = 1;
		return iRetCode;
	}
	fprintf(f, "%d\n", (int)iNumAvgs);
	for(curAvg=0; curAvg<iNumAvgs; curAvg++) {
		double u, v, w, t;
		double uu, uv, uw, vv, vw, ww;
		double ut, vt, wt;
		double tt;
		int n = numSum[curAvg];
		if(n > 0) {
			
			// Current averages and covariances
			
			u  = sumU[curAvg] / n;
			v  = sumV[curAvg] / n;
			w  = sumW[curAvg] / n;
			t  = sumT[curAvg] / n;
			uu = sumUU[curAvg] / n - u*u;
			uv = sumUV[curAvg] / n - u*v;
			uw = sumUW[curAvg] / n - u*w;
			vv = sumVV[curAvg] / n - v*v;
			vw = sumVW[curAvg] / n - v*w;
			ww = sumWW[curAvg] / n - w*w;
			ut = sumUT[curAvg] / n - u*t;
			vt = sumVT[curAvg] / n - v*t;
			wt = sumWT[curAvg] / n - w*t;
			tt = sumTT[curAvg] / n - t*t;
			
			scalarVel = sumVel[curAvg] / n;
			vel2      = sumVel2[curAvg] / n;
			
			// First rotation
			
			double rTheta = atan2(v,u);
			double cr     = cos(rTheta);
			double sr     = sin(rTheta);
			double cr2    = cos(2.*rTheta);
			double sr2    = sin(2.*rTheta);
			
			double ur =  u*cr + v*sr;
			double vr = -u*sr + v*cr;
			double wr =  w;
			
			double utr =  ut*cr + vt*sr;
			double vtr = -ut*sr + vt*cr;
			double wtr =  wt;
			
			double uur = uu*cr*cr + vv*sr*sr + uv*sr2;
			double uvr = 0.5*(2.*uv*cr2 + (vv-uu)*sr2);
			double uwr = uw*cr + vw*sr;
			double vvr = vv*cr*cr - 2.*uv*cr*sr + uu*sr*sr;
			double vwr = vw*cr - uw*sr;
			double wwr = ww;
			
			// Second rotation
			
			rPhi = 0.5*atan2(2.*vw, vv-ww);
			double cs     = cos(rPhi);
			double ss     = sin(rPhi);
			double cs2    = cos(2.*rPhi);
			double ss2    = sin(2.*rPhi);
			
			double us =  ur*cs + wr*ss;
			double vs =  vr;
			double ws =  wr*cs - ur*ss;
			
			double uts =  utr*cs + wtr*ss;
			double vts =  vtr;
			double wts =  wtr*cs - utr*ss;
			
			double uus = uur*cs*cs + wwr*ss*ss + uwr*ss2;
			double uvs = uvr*cs + vwr*ss;
			double uws = 0.5*(2.*uwr*cs2 + (wwr-uur)*ss2);
			double vvs = vvr;
			double vws = vwr*cs - uvr*ss;
			double wws = wwr*cs*cs - 2.*uwr*cs*ss + uur*ss*ss;
			
			// Quantities to display
			vel = sqrt(u*u + v*v);
			dir = 180.*atan2(-u,-v)/3.1415927;
			if(dir < 0.) dir += 360.;
			velStd = sqrt(vel2 - scalarVel*scalarVel);
			uAvg = u;
			vAvg = v;
			wAvg = w;
			tAvg = t;
			uStd = sqrt(uus);
			vStd = sqrt(vvs);
			wStd = sqrt(wws);
			tStd = sqrt(tt);
			uvCov = uvs;
			uwCov = uws;
			vwCov = vws;
			utCov = uts;
			vtCov = vts;
			wtCov = wts;
			uStar = sqrt(sqrt(uwCov*uwCov + vwCov*vwCov));
			H0    = 350.125 * 1013.0 * exp(-0.0342/(tAvg+273.15)*z) / (tAvg + 273.15) * wtCov;
			lm1   = -0.4*9.807/(tAvg+273.15) * wtCov / (uStar*uStar*uStar);
			
		}
		
		else {
			
			scalarVel = -9999.9;
			vel       = -9999.9;
			dir       = -9999.9;
			velStd    = -9999.9;
			uAvg      = -9999.9;
			vAvg      = -9999.9;
			wAvg      = -9999.9;
			tAvg      = -9999.9;
			uStd      = -9999.9;
			vStd      = -9999.9;
			wStd      = -9999.9;
			tStd      = -9999.9;
			uvCov     = -9999.9;
			uwCov     = -9999.9;
			vwCov     = -9999.9;
			utCov     = -9999.9;
			vtCov     = -9999.9;
			wtCov     = -9999.9;
			uStar     = -9999.9;
			H0        = -9999.9;
			lm1       = -9999.9;
			rPhi      = -9999.9;
			
		}
		
		// Write data
		fprintf(f, "%f\n%f\n%d\n%f\n%f\n%f\n%f\n%f\n%f\n%f\n%f\n%f\n%f\n%f\n%f\n%f\n%f\n%f\n%f\n%f\n%f\n%f\n%f\n%f\n%f\n",
			fromTime[curAvg], avgDepth[curAvg], numSum[curAvg],
			vel, dir, tAvg, scalarVel, velStd, uAvg, vAvg, wAvg, uStd, vStd, wStd, tStd,
			uvCov, uwCov, vwCov, utCov, vtCov, wtCov, uStar, H0, lm1, rPhi*180./3.1415927
		);
		
	}
	fclose(f);

	// Leave
	return iRetCode;

};
