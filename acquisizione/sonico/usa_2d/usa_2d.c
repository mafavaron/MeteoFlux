#include "st_lib.h"
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>
#include <signal.h>
#include <ctype.h>
#include <math.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "iniparser.h"

#define ANEMOMETER_HEIGHT      3.5
#define PROCESSING_INTERVAL  600
#define AVG_PERIOD		    3600
#define STATUS_INTERVAL       10
#define RAWDATA_INTERVAL       5

#define CMD_BUF_SIZE           1
#define DISPLAY_BUFFER_SIZE  200

#define MAX_PART 1000000
#define MAX_PARTS_PER_STEP 10
#define MAX_SOURCES 999

#define MAX_N_E 100
#define MAX_N_N 100

#define TRUE  -1
#define FALSE  0

#define USA_FREQ         10
#define USA_OVERSAMPLING 4
#define USA_ANALOG       0
#define ONE_HOUR         3600

#define MAX_AVGS 16

void sigterm(int signo) {
	syslog(LOG_INFO, "Got SIGTERM, exiting");
	exit(0);
}

void sighup(int signo) {
	syslog(LOG_INFO, "Got SIGHUP, and logging it only");
}


static void *cleanProcesses(void *arg) {

	while(1) {

		// Wait ten seconds, then scan process list to check if any
		// descendant has terminated; in case, remove it from list
		// (that is, "delete zombie processes")
		sleep(10);
		pid_t iPID = waitpid(-1, NULL, WNOHANG | WUNTRACED);

	}

}


int main(int argc, char** argv) {

	int  i;
	int  iEpochTemp;
	int  iEpoch0 = 0, iEpoch1 = 0, iEpoch2 = 0, iEpoch3 = 0, iEpoch4 = 0, iEpoch5 = 0, iEpoch6 = 0;
	int  iYear, iMonth, iDay, iHour, iMinute, iSecond;
	short int  iTimeStamp;
	int  result;
	int  hourChanged;
	int  timeForProcessing;
	char serialPortName[16];
	char configFile[256];
	int  debug = FALSE;
	int  port;
	int  iNumChars;
	int  iRetCode;
	char buffer[64];
	short int ivData[5];
	FILE* f;
	int iRecordType;
	int justStarted = TRUE;
	int iNumDataFromStart = 0;
	char cmdBuffer[CMD_BUF_SIZE+1];
	double z;
	
	// Get input parameters
	if(argc != 3 && argc != 4) {
		printf("usa_2d - uSonic-2 data acquisition task\n\n");
		printf("Usage:\n\n");
		printf("  usa_2d <rs232> <cfgFile> [--debug]\n\n");
		exit(1);
	}
	strcpy(serialPortName, argv[1]);
	strcpy(configFile, argv[2]);
	debug = (argc==4);
	
	// Get configuration data from configFile
	// -1- Check file exists
	FILE* fc = fopen(configFile, "r");
	if(!fc) {
		syslog(LOG_ERR, "Configuration file missing or not found");
		exit(20);
	}
	fclose(fc);
	// -1- Get general configuration data
	dictionary* ini = iniparser_load(configFile);
	int iFuse = iniparser_getint(ini, (const char *)"General:Fuse", 1);
	if(iFuse < -12) iFuse = -12;
	if(iFuse >  12) iFuse =  12;
	z = iniparser_getdouble(ini, (const char *)"General:AnemometerHeight", 10.0);
	if(z <= 0.5) z = 0.5;
	// -1- Timing
	int iAveragingPeriod = iniparser_getint(ini, (const char *)"Timing:AveragingPeriod", AVG_PERIOD);
	if(iAveragingPeriod > AVG_PERIOD) iAveragingPeriod = AVG_PERIOD;
	if(iAveragingPeriod < 1) iAveragingPeriod = 1;
	int iStatusInterval = iniparser_getint(ini, (const char *)"Timing:StatusInterval", STATUS_INTERVAL);
	if(iStatusInterval > STATUS_INTERVAL) iStatusInterval = STATUS_INTERVAL;
	if(iStatusInterval < 1) iStatusInterval = 1;
	// -1- Ultrasonic anemometer configuration data
	int iSamplingRate = iniparser_getint(ini, (const char *)"SonicAnemometer:SamplingFrequency", USA_FREQ);
	if(iSamplingRate > USA_FREQ) iSamplingRate = USA_FREQ;
	if(iSamplingRate < 1) iSamplingRate = 1;
	int iRawPerSample = iniparser_getint(ini, (const char *)"SonicAnemometer:ElementaryDataPerSample", 2);
	if(iRawPerSample > 4) iRawPerSample = USA_OVERSAMPLING;
	if(iRawPerSample < 1) iRawPerSample = 1;
	
	// Check whether start is to be made by looking at file
	// '/var/run/usa_2d.pid'
	if(!isUniqueInstance(LOCK_FILE_2D)) {
		syslog(LOG_ERR, "Attempting to start multiple instance of 'usa_2d'");
		exit(30);
	}
	
	// Manage start mode (normal is as "daemon")
	if(debug) {
		startconsole("usa_2d");
	}
	else {
		daemonize("usa_2d");
	}
	
	// Assign signal handlers
	struct sigaction sa;
	sa.sa_handler = sigterm;
	sigemptyset(&sa.sa_mask);
	sigaddset(&sa.sa_mask, SIGHUP);
	sa.sa_flags = 0;
	if(sigaction(SIGTERM, &sa, NULL) < 0) {
		syslog(LOG_ERR, "Can't catch SIGTERM: %s", strerror(errno));
		exit(3);
	}
	sa.sa_handler = sighup;
	sigemptyset(&sa.sa_mask);
	sigaddset(&sa.sa_mask, SIGTERM);
	sa.sa_flags = 0;
	if(sigaction(SIGHUP, &sa, NULL) < 0) {
		syslog(LOG_ERR, "Can't catch SIGHUP: %s", strerror(errno));
		exit(4);
	}

	// Connect serial port
	port = connect(serialPortName, B9600);
	if(port <= 0) {
		syslog(LOG_ERR, "Serial port %s not opened", serialPortName);
		if(debug) printf("Serial port %s not opened\n", serialPortName);
		exit(3);
	}

	// Configure ultrasonic anemometer
	strcpy(buffer, "AT=0\r\n");
	send(port, buffer);
	sprintf(buffer, "AV=%d\r\n", iRawPerSample);
	send(port, buffer);
	sprintf(buffer, "SF=%d\r\n", iSamplingRate*1000*iRawPerSample);
	send(port, buffer);
	strcpy(buffer, "OD=2049\r\n");
	send(port, buffer);
	
	// Start process monitoring thread
	pthread_t tid;
	pthread_create(&tid, NULL, cleanProcesses, NULL);
	
	// Create command input named pipe, if it does not exist yet
	// (normally it does not on start, as pipe resides in RAM disk)
	if(access(CMD_INPUT, F_OK) == -1) {
		iRetCode = mkfifo(CMD_INPUT, 0777);
		if(iRetCode != 0) {
			syslog(LOG_ERR, "Command input pipe not created");
			if(debug) printf("Command input pipe not created\n");
			exit(4);
		}
	}
	// Post-condition: pipe exists, should be connected
	
	// Connect command input named pipe in non-blocking mode for read
	int cmdInput = open(CMD_INPUT, O_RDONLY | O_NONBLOCK);
	if(cmdInput == -1) {
		syslog(LOG_ERR, "Command input pipe not opened");
		if(debug) printf("Command input pipe not opened\n");
		exit(5);
	}
	
	// Main loop: get data from port and log them to disk
	result = nowAbsolute(iFuse, &iEpoch0, &iYear, &iMonth, &iDay, &iHour, &iMinute, &iSecond);
	openDataFile2D(&f, DATA_SET, iYear, iMonth, iDay, iHour);
	if(f == NULL) {
		syslog(LOG_ERR, "Initial output data file not opened");
		if(debug) printf("Initial output data file not opened\n");
		exit(6);
	}
	int iNumSonicPackets = 0;
	unsigned int iNumTotPackets = 0;
	unsigned int iNumValidPackets = 0;
	while(1) {
		
		// Inspect command input pipe: if it contains a command execute it on the fly
		cmdBuffer[0] = '\0';
		cmdBuffer[1] = '\0';
		int iNumData = read(cmdInput, cmdBuffer, CMD_BUF_SIZE);
		if(iNumData > 0) {
			
			// Perform an orderly stop
			if(strcmp(cmdBuffer, "s") == 0) {
				close(cmdInput); // Release the input command queue
				syslog(LOG_INFO, "Stopped by external program through 'cmd_server' pipe");
				return 0;
			}
			
		}
	
		// Get a data line, assign it time stamps as appropriate
		iNumChars = receive(port, sizeof(buffer), (char)0x0a, buffer);
		iTimeStamp = nowAbsolute(iFuse, &iEpochTemp, &iYear, &iMonth, &iDay, &iHour, &iMinute, &iSecond);
		double dTimeStamp = nowRelative();
		
		// Hour change detected: close current file, open next
		hourChanged = isNewAbsoluteTimeStep(iFuse, &iEpoch2, ONE_HOUR);
		if(hourChanged) {
			fclose(f);
			openDataFile2D(&f, DATA_SET, iYear, iMonth, iDay, iHour);
		};
		
		// Start processing on "current" file
		timeForProcessing = isNewAbsoluteTimeStep(iFuse, &iEpoch1, iAveragingPeriod);
		if(timeForProcessing && !justStarted) {
			
			// Flush data to disk, to ensure all most recent data are available
			fflush(f);
		
			time_t tTime;
			struct tm *ptTime;
			tTime = (time_t)(iEpoch1 - iAveragingPeriod);
			ptTime = gmtime(&tTime);
			syslog(LOG_ERR, "About to start processing");
			dataProcessing2D(
				DATA_PROCESSING_2D_EXEC,
				"proc2d",
				DATA_SET,
				ptTime,
				iAveragingPeriod,
				iFuse
			);
			
		}
		
		// Store the data line just read (or perform some emergency processing)
		iNumTotPackets++;
		if(iNumChars > 0) {

			iRetCode = readDataLine2D(iTimeStamp, buffer, ivData, debug);
			if(iRetCode == 0) {
				fwrite(&ivData, sizeof(iTimeStamp), 5, f);
				iNumValidPackets++;
			}

		}
		else if(iNumChars != -1) {
			// No timeout, yet some error
			// printf("%04d - Chars: %d\n", iTimeStamp, iNumChars);
		}
		else {
			// Timeout: try to reset port and sonic
			iRetCode = send(port, "RS\r");
			disconnect(port);
			port = connect(serialPortName, B9600);
		}
		
		// Start status assessment/notification
		timeForProcessing = isNewAbsoluteTimeStep(iFuse, &iEpoch5, iStatusInterval);
		if(timeForProcessing && !justStarted) {

			int i;

			FILE* stt = fopen("/mnt/ramdisk/Usa2DStatus.txt", "w");
			fprintf(stt,"[Timing]\n");
			fprintf(stt, "Uptime = %f\n", dTimeStamp);
			fprintf(stt, "Sysclk = %4.4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d\n", iYear, iMonth, iDay, iHour, iMinute, iSecond);
			fprintf(stt,"\n[Packets]\n");
			fprintf(stt, "Total = %d\n", iNumTotPackets);
			fprintf(stt, "Valid = %d\n", iNumValidPackets);
			fclose(stt);

			FILE* stb = fopen("/mnt/ramdisk/Usa2DStatus.bin", "wb");
			fwrite((void*)&dTimeStamp, sizeof(dTimeStamp), (size_t)1, stb);
			fwrite((void*)&iYear, sizeof(iYear), (size_t)1, stb);
			fwrite((void*)&iMonth, sizeof(iMonth), (size_t)1, stb);
			fwrite((void*)&iDay, sizeof(iDay), (size_t)1, stb);
			fwrite((void*)&iHour, sizeof(iHour), (size_t)1, stb);
			fwrite((void*)&iMinute, sizeof(iMinute), (size_t)1, stb);
			fwrite((void*)&iSecond, sizeof(iSecond), (size_t)1, stb);
			fwrite((void*)&iNumTotPackets, sizeof(iNumTotPackets), (size_t)1, stb);
			fwrite((void*)&iNumValidPackets, sizeof(iNumValidPackets), (size_t)1, stb);
			fclose(stb);

			iNumTotPackets = 0;
			iNumValidPackets = 0;
			
		}
		
		// One loop made to this point: "just started" condition may now be reversed
		if(justStarted) justStarted = FALSE;
		
	}
	
	// Leave
	disconnect(port);
	fclose(f);
	exit(0);

}
