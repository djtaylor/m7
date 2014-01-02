#!/bin/bash

test_init() {
	TEST_INIT_ARGS=( "$@" )
	if [ ! -f "${TEST_INIT_ARGS[0]}" ]; then
		log "error" "No test plan (arg1) supplied..."
		exit 1
	fi
	TEST_INIT_ID="$(xml "parse" "${TEST_INIT_ARGS[0]}" "id/text()")"
	if [ -d ~/lock/$TEST_INIT_ID ]; then
		log "error" "A test with the ID '$TEST_INIT_ID' already exists. Please specify a unique ID in the test plan: '${TEST_INIT_ARGS[0]}'"
		exit 1
	fi
	mkdir -p ~/lock/$TEST_INIT_ID
	touch ~/lock/$TEST_INIT_ID/runtime && date +"%Y-%m-%d %H:%M:%S" > ~/lock/$TEST_INIT_ID/runtime
}

readonly -f test_init