#!/usr/bin/python

import meteoflux
import user
import local_site
import sys


if __name__ == "__main__":
	
	# Inform application starts
	meteoflux.logMessage("Info - Meteoflux Core data logger starting")
	
	# Set defaults from local configuration
	meteoflux.makeDir(local_site.RAW_DATA_PATH)
	meteoflux.makeDir(local_site.PROCESSED_DATA_PATH)
	meteoflux.makeDir(local_site.DIAGNOSTIC_DATA_PATH)
	meteoflux.makeDir(local_site.ALARM_LISTS_PATH)

	# Clean yaml file containing declared data sets and vaariables
	dst = open("/mnt/ramdisk/dataloggerSets.yaml", "w")
	dst.write("DataSets : \n")
	dst.close()
	
	# User-programmed initialization
	user.initialize()
	
	# Some modules must have been specified. If they are, check their addresses do not overlap.
	addresses = []
	for i in range(len(meteoflux.modules)):
		addresses.append( meteoflux.modules[i].GetModuleAddress() )
	for i in range(len(meteoflux.sa8000s)):
		addresses.append( meteoflux.sa8000s[i].GetModuleAddress() )
	if addresses == []:
		meteoflux.logMessage("Error - No modules configured: exiting execution")
		sys.exit(1)
	for i in range(len(addresses)-1):
		for j in range(i+1,len(addresses)):
			if addresses[i] == addresses[j]:
				meteoflux.logMessage("Error - Two devices have been configured with overlapping address %d: exiting execution" % addresses[i])
				sys.exit(1)
	
	# Open serial port - but only if some real module has been requested by user.
	# During test this might not be, if "AD_sim" simulated modules only are specified.
	anyRealModule = False
	meteoflux.RS485(
		meteoflux.getPort()
	)
	meteoflux.logMessage("Info - Serial port initialization completed")
	
	# Confirm all modules in configuration are ready and alive (always true for "AD_sim" modules)
	anyFailure = False
	for module in meteoflux.modules:
		if not module.CheckModule():
			anyFailure = True
			meteoflux.logMessage("Warning - Configured module %s at address %02x not responding" % (module.GetModuleType(), module.GetModuleAddress()))
			break
	if meteoflux.GetBlockOnModuleFailure() and anyFailure:
		meteoflux.logMessage("Error - At least one configured module did not answer")
		sys.exit(2)
	
	# Main loop
	numIterationsAtCheck = 0
	checkEverySteps      = meteoflux.GetIterationsAtModuleCheck()
	meteoflux.assignNextAveragingTime()
	while True:
		
		# Wait until next step, according to sampling time
		meteoflux.waitUntilNext()
		
		# Execute user code
		user.loop()
		
		# Every here and there, check all modules are still alive. If any is not, act
		# as established in configuration
		if checkEverySteps > 0:
			numIterationsAtCheck += 1
			if numIterationsAtCheck % checkEverySteps == 0:
				numIterationsAtCheck = 0
				anyFailure = False
				for module in meteoflux.modules:
					if not module.CheckModule():
						anyFailure = True
						meteoflux.logMessage("Warning - Configured module %s at address %02x not responding" % (module.GetModuleType(), module.GetModuleAddress()))
						break
				if meteoflux.GetBlockOnModuleFailure() and anyFailure:
					meteoflux.logMessage("Error - At least one configured module did not answer")
					sys.exit(3)
				meteoflux.SetAllModulesRunning( not anyFailure )
			
