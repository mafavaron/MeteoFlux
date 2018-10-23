# Diagnostic function and depth

import base_funcs

_ALLOWED_ITERATIONS_AT_CHECK = [0, 10, 20, 30, 40, 50, 60]

_blockOnModuleFailure    = False
_iterationsAtModuleCheck = 10
_allModulesOperational   = True

def GetBlockOnModuleFailure():
	
	global _blockOnModuleFailure
	
	return _blockOnModuleFailure
	

def SetBlockOnModuleFailure(blockOnModuleFailure):
	
	global _blockOnModuleFailure
	
	_blockOnModuleFailure = blockOnModuleFailure
	

def GetIterationsAtModuleCheck():
	
	global _iterationsAtModuleCheck
	
	return _iterationsAtModuleCheck
	

def SetIterationsAtModuleCheck(iterationsAtModuleCheck):
	
	global _iterationsAtModuleCheck, _ALLOWED_ITERATIONS_AT_CHECK
	
	_iterationsAtModuleCheck = base_funcs.closest(iterationsAtModuleCheck, _ALLOWED_ITERATIONS_AT_CHECK)
	

def CheckAllModulesRunning():

	global _allModulesOperational
	
	return _allModulesOperational
	

def SetAllModulesRunning( state ):
	
	global _allModulesOperational
	
	_allModulesOperational = state
	
