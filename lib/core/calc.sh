#!/bin/bash

# Results Calculation Library
#
# The following library is used to calculate values such as the averages
# in an array for speed, download time, etc.

calc() {
	
	# Calculation Arguments
	CALC_ARGS=( "$@" )
	
	case "${CALC_ARGS[0]}" in
		
		# Calculate Download Time (seconds)
		#
		# The following method takes a time argument in the HH:MM:SS format and converts
		# it to a single value of seconds.
		"dlTime")
			echo "${CALC_ARGS[0]}" | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }'
			;;
		
		# Calculate Download Speed (Kbps)
		#
		# The following method takes an average download speed from the output from
		# curl, and calculates the speed in Kbps. This method converts from Bps/Mbps,
		# to Kbps.
		"xferSpeed")
			
			# Convert from 'Bps' to 'Kbps'
			if [[ ${CALC_ARGS[0]} =~ ^[0-9]*$ ]]; then
				CALC_XFER_SPEED_RAW="$(echo "${CALC_ARGS[0]}/1024" | bc)"
			fi
			
			# Format 'Kbps'
			if [[ ${CALC_ARGS[0]} =~ ^[0-9]*k$ ]]; then
				CALC_XFER_SPEED_RAW="$(echo ${CALC_ARGS[0]} | sed "s/\(^[0-9]*\).*$/\1/g")"
			fi
			
			# Convert from 'Mbps' to 'Kbps'
			if [[ ${CALC_ARGS[0]} =~ ^[0-9\.]*M$ ]]; then
				CALC_XFER_SPEED_RAW="$(echo ${CALC_ARGS[0]} | sed "s/\(^[0-9\.]*\)M$/\1/g")"
				CALC_XFER_SPEED_RAW="$(echo "$THREAD_AVG_SPEED_RAW*1024" | bc)"
			fi
			
			# Return the speed in 'Kbps'
			echo "$CALC_XFER_SPEED_RAW"
			;;
		
		# Calculate Array Average
		#
		# The following method expands an array names, gets the size of the array,
		# and calculates the average value before returning. The source must contain
		# only numerical values.
		"arrayAvg")
			
			# Expand the source array
			declare -a CALC_SOURCE_ARRAY=("${!1}")
			
			# Find the average value for the array
			CALC_ARRAY_COUNT="${#CALC_SOURCE_ARRAY[@]}"
			CALC_ARRAY_VALUE_SUM=0
			CALC_ARRAY_VALUE_RESULT=""
			for CALC_ARRAY_VALUE in "${CALC_SOURCE_ARRAY[@]}"
			do
				CALC_ARRAY_VALUE_SUM="$(echo "$CALC_ARRAY_VALUE_SUM+$CALC_ARRAY_VALUE" | bc)"
			done
			CALC_ARRAY_VALUE_RESULT="$(echo "$CALC_ARRAY_VALUE_SUM/$CALC_ARRAY_COUNT" | bc)"
			
			# Return the average result
			echo "$CALC_ARRAY_VALUE_RESULT"
			;;
			
		*)
			log "error" "Invalid argument supplied to calculation function: '${CALC_ARGS[0]}'"
		
	esac
}

readonly -f calc