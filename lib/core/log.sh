#!/bin/bash

# M7 Logging Library
#
# This library file is used to handle logging platform messages.

log() {
	
	# Log Arguments
	#
	# arg1 -> Log message type
	# arg2 -> Log message
	LOG_ARGS=( "$@" )
	
	# Initialize the log files
	mkdir -p ~/log
	if [ ! -f "$M7LOG_ERROR" ]; then
		touch $M7LOG_ERROR
	fi
	if [ ! -f "$M7LOG_MAIN" ]; then
		touch $M7LOG_MAIN
	fi
	
	case "${LOG_ARGS[0]}" in
	
		"info")
			echo -e "${LOG_ARGS[1]}"
			echo -e "$(date +"%m-%d %H:%M:%S") [$(hostname -s)]: ${LOG_ARGS[1]}" >> $M7LOG_MAIN
			;;
			
		"info-proc")
			echo -e -n "${LOG_ARGS[1]}"
			echo -e -n "$(date +"%m-%d %H:%M:%S") [$(hostname -s)]: ${LOG_ARGS[1]}" >> $M7LOG_MAIN
			;;
	
		"error")
			echo -e "ERROR: ${LOG_ARGS[1]}"
			echo -e "$(date +"%m-%d %H:%M:%S") [$(hostname -s)]: ${LOG_ARGS[1]}" >> $M7LOG_ERROR
			;;
			
		*)
			echo -e "$(date +"%m-%d %H:%M:%S") [$(hostname -s)]: Invalid log message type - '${LOG_ARGS[0]}'" >> $M7LOG_ERROR

	esac
	
}

readonly -f log