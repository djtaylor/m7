#!/bin/bash

# M7 XML Parser
#
# This library is used to parse values from an XML test plan.

xml() {
	
	# XML Parser Arguments
	#
	# !arg1 -> XML action
	# !arg2 -> Target XML file
	# !arg3 -> Target XML property/attribute
	XML_ARGS=( "$@" )
	
	case "${XML_ARGS[0]}" in
		
		"parse")
			echo "cat //plan/${XML_ARGS[2]}" | xmllint --shell "${XML_ARGS[1]}" | sed 1d | sed 2d
			;;
		
	esac
	
}

readonly -f xml