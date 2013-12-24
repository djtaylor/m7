#!/bin/bash

# Web Test - Single File Download
#
# !arg0		'Test plan ID'
# !arg1		'Test definition ID'
# !arg2 	'Test plan category'
# !arg3		'Test plan thread number'
# !arg4		'Test plan target host'
# !arg5		'Test plan host protocol'
# !arg6		'Host relative file path'
# !arg7		'Number of samples per thread'
# !arg8     'Test category type'
SD_TEST_ARGS=(\
"{TEST_PLAN_ID}"
"{TEST_DEF_ID}"
"{TEST_CAT}"
"{TEST_THREAD_NUM}"
"{TEST_TARGET_HOST}"
"{TEST_HOST_PROTO}"
"{TEST_FILE_PATH}"
"{TEST_SAMPLES}"
"{TEST_CAT_TYPE}")

# Set the base directory from the plan ID, test ID, and thread number
SD_TEST_BASE=~/output/${SD_TEST_ARGS[0]}/local/test-${SD_TEST_ARGS[1]}/thread-${SD_TEST_ARGS[3]}
mkdir -p $SD_TEST_BASE/tmp

# Generate the test lockfile directory and create the test thread lockfile
SD_TEST_LOCK_DIR=~/lock/${SD_TEST_ARGS[0]}/local
SD_TEST_LOCK="$SD_TEST_LOCK_DIR/test-${SD_TEST_ARGS[1]}.thread-${SD_TEST_ARGS[3]}"
mkdir -p $SD_TEST_LOCK_DIR
touch $SD_TEST_LOCK

# Set the test output log file
SD_TEST_LOG="$SD_TEST_BASE/output.log"

# Validate Host \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
if [ -z "${SD_TEST_ARGS[4]}" ]; then
	echo "ERROR: No target host specified..." | tee $SD_TEST_LOG
    exit 1
else
	
	# Make sure the protocol is valid
	if [ "${SD_TEST_ARGS[5]}" != "http" ] && [ "${SD_TEST_ARGS[5]}" != "https" ]; then
		echo "ERROR: Protocol must be either 'http' or 'https'..." | tee $SD_TEST_LOG
	    exit 1
	else

        # Samples Counter
    	SD_SAMPLES_COUNT="0"

        # Start the test loop
        echo "######################################################################" | tee $SD_TEST_LOG
        echo "INITIALIZING TEST: '${SD_TEST_ARGS[2]}':'${SD_TEST_ARGS[8]}'" | tee -a $SD_TEST_LOG
        echo "> Test Thread:	  '${SD_TEST_ARGS[3]}'" | tee -a $SD_TEST_LOG
        echo "> Target Host:      '${SD_TEST_ARGS[4]}'" | tee -a $SD_TEST_LOG
        echo "> Target Protocol:  '${SD_TEST_ARGS[5]}'" | tee -a $SD_TEST_LOG
    	echo "> Target File Path: '${SD_TEST_ARGS[5]}://${SD_TEST_ARGS[4]}${SD_TEST_ARGS[6]}'" | tee -a $SD_TEST_LOG
    	echo "> Download Samples: '${SD_TEST_ARGS[7]}'" | tee -a $SD_TEST_LOG
    	echo "> Test Log File:    '$SD_TEST_LOG'" | tee -a $SD_TEST_LOG
        echo "######################################################################" | tee -a $SD_TEST_LOG
        while [ "${SD_TEST_ARGS[7]}" -gt "$SD_SAMPLES_COUNT" ]
        do
        	let SD_SAMPLES_COUNT++
            echo "----------------------------------------------------------------------" | tee -a $SD_TEST_LOG
        	echo "RUNNING TEST SAMPLE('$SD_SAMPLES_COUNT')" | tee -a $SD_TEST_LOG
            echo "----------------------------------------------------------------------" | tee -a $SD_TEST_LOG
            cd $SD_TEST_BASE/tmp
            curl -v -k -O ${SD_TEST_ARGS[5]}://${SD_TEST_ARGS[4]}/${SD_TEST_ARGS[6]} 2>&1 | tee -a $SD_TEST_LOG
        done
        echo "######################################################################" | tee -a $SD_TEST_LOG
        echo "TEST COMPLETED" | tee -a $SD_TEST_LOG
        echo "######################################################################" | tee -a $SD_TEST_LOG
        cd
		
        # Remove the temporary directory and lock file
        rm -rf $SD_TEST_BASE/tmp
        rm -f $SD_TEST_LOCK
	fi
fi

# Self destruct the script
rm -f /tmp/${SD_TEST_ARGS[0]}.${SD_TEST_ARGS[2]}.test-${SD_TEST_ARGS[1]}.thread-${SD_TEST_ARGS[3]}.sh