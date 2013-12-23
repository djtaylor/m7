#!/bin/bash

# Curl Parsing Library
#
# This library is designed as a shortcut to parse the results from the final
# line in a curl command output to retrieve values such as download time,
# average speed, etc.

curl_parse() {
	
	# Curl Parse Arguments
	#
	# arg1 -> Data to retrieve from the string
	# arg2 -> Curl results string to parse
	CURL_ARGS=( "$@" )
	
	check_curl_string() {
		if [ -z "${CURL_ARGS[1]}" ]; then
			return 1
		fi	
	}
	
	case "${CURL_ARGS[0]}" in
		
		"avgSpeed")
			if [ "$(check_curl_string)" = "1" ]; then
				log "error" "No target string to parse supplied..."
			else
				echo "${CURL_ARGS[1]}" | sed "s/^[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*\([^ ]*\).*$/\1/g"
			fi	
			;;
		
		"dlTime")
			if [ "$(check_curl_string)" = "1" ]; then
				log "error" "No target string to parse supplied..."
			else
				echo "${CURL_ARGS[1]}" | sed "s/^[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*[^ ][ ]*\([^ ]*\).*$/\1/g"
			fi	
			;;
		
		*)
			log "error" "Invalid property for Curl parsing: '${CURL_ARGS[0]}'"
		
	esac
	
}

readonly -f curl_parse