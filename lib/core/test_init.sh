#!/bin/bash

test_init() {
	TEST_INIT_ARGS=( "$@" )
	
	# Only run on the director node
	if [ ! -z "$(sqlite3 ~/db/cluster.db "SELECT * FROM M7_Nodes WHERE Type='director' AND Name='$(hostname -s)';")" ]; then
	
		# Make sure a plan file is specified
		if [ ! -f "${TEST_INIT_ARGS[0]}" ]; then
			log "error" "No test plan (arg1) supplied..."
			exit 1
		fi
		
		# Grab the test plan ID
		TEST_INIT_ID="$(xml "parse" "${TEST_INIT_ARGS[0]}" "id/text()")"
		
		# Make sure a duplicate test isn't already running
		if [ -d ~/lock/$TEST_INIT_ID ]; then
			log "error" "A test with the ID '$TEST_INIT_ID' already exists. Please specify a unique ID in the test plan: '${TEST_INIT_ARGS[0]}'"
			exit 1
		fi
		
		# Create the test lock directory and runtime file
		mkdir -p ~/lock/$TEST_INIT_ID
		touch ~/lock/$TEST_INIT_ID/runtime && date +"%Y-%m-%d %H:%M:%S" > ~/lock/$TEST_INIT_ID/runtime
	fi
}

readonly -f test_init