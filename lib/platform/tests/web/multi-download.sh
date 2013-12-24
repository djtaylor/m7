#!/bin/bash

# Web Test - Multiple File Download
#
# !arg0		'Test plan ID'
# !arg1		'Test definition ID'
# !arg2 	'Test plan category'
# !arg3		'Test plan thread number'
# !arg4		'Test plan target host'
# !arg5		'Test plan host protocol'
# !arg6		'Host relative file path, must be an array of files for multi-download'
# !arg7		'Number of samples per thread'
# !arg8     'Test category type'
MD_TEST_ARGS=(\
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
MD_TEST_BASE=~/output/${MD_TEST_ARGS[0]}/local/test-${MD_TEST_ARGS[1]}/thread-${MD_TEST_ARGS[3]}
mkdir -p $MD_TEST_BASE/tmp

# Generate the test lockfile directory and create the test thread lockfile
MD_TEST_LOCK_DIR=~/lock/${MD_TEST_ARGS[0]}/local
MD_TEST_LOCK="$MD_TEST_LOCK_DIR/test-${MD_TEST_ARGS[1]}.thread-${MD_TEST_ARGS[3]}"
mkdir -p $MD_TEST_LOCK_DIR
touch $MD_TEST_LOCK

# Set the test output log file
MD_TEST_LOG="$MD_TEST_BASE/output.log"

# Validate Host \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
if [ -z "${MD_TEST_ARGS[4]}" ]; then
	echo "ERROR: No target host specified..." | tee $MD_TEST_LOG
    exit 1
else
	
	# Make sure the protocol is valid
	if [ "${MD_TEST_ARGS[5]}" != "http" ] && [ "${MD_TEST_ARGS[5]}" != "https" ]; then
		echo "ERROR: Protocol must be either 'http' or 'https'..." | tee $MD_TEST_LOG
	    exit 1
	else

		# Convert the files string into an array
		XFORM_OIFS="$IFS"
		IFS=";" read -a MD_FILES_ARRAY <<< "${MD_TEST_ARGS[6]}"
		IFS="$XFORM_OIFS"

        # Samples Counter
    	MD_SAMPLES_COUNT="0"

        # Start the test loop
        echo "######################################################################" | tee $MD_TEST_LOG
        echo "INITIALIZING TEST: '${MD_TEST_ARGS[2]}':'${MD_TEST_ARGS[8]}'" | tee -a $MD_TEST_LOG
        echo "> Test Thread:	  '${MD_TEST_ARGS[3]}'" | tee -a $MD_TEST_LOG
        echo "> Target Host:      '${MD_TEST_ARGS[4]}'" | tee -a $MD_TEST_LOG
        echo "> Target Protocol:  '${MD_TEST_ARGS[5]}'" | tee -a $MD_TEST_LOG
    	echo "> Target File Path: '${MD_TEST_ARGS[5]}://${MD_TEST_ARGS[4]}${MD_TEST_ARGS[6]}'" | tee -a $MD_TEST_LOG
    	echo "> Download Samples: '${MD_TEST_ARGS[7]}'" | tee -a $MD_TEST_LOG
    	echo "> Test Log File:    '$MD_TEST_LOG'" | tee -a $MD_TEST_LOG
        echo "######################################################################" | tee -a $MD_TEST_LOG
        while [ "${MD_TEST_ARGS[7]}" -gt "$MD_SAMPLES_COUNT" ]
        do
        	let MD_SAMPLES_COUNT++
            echo "----------------------------------------------------------------------" | tee -a $MD_TEST_LOG
        	echo "RUNNING TEST SAMPLE('$MD_SAMPLES_COUNT')" | tee -a $MD_TEST_LOG
            echo "----------------------------------------------------------------------" | tee -a $MD_TEST_LOG
            cd $MD_TEST_BASE/tmp
            
            # Process the files array
			MD_FILE_COUNT=0
			for MD_FILE in "${MD_FILES_ARRAY[@]}"
			do
				let MD_FILE_COUNT++
				echo "# Sample '$MD_SAMPLES_COUNT' - File '$MD_FILE_COUNT'" | tee -a $MD_TEST_LOG
				curl -v -k -O ${MD_TEST_ARGS[5]}://${MD_TEST_ARGS[4]}/$MD_FILE 2>&1 | tee -a $MD_TEST_LOG
			done
        done
        echo "######################################################################" | tee -a $MD_TEST_LOG
        echo "TEST COMPLETED" | tee -a $MD_TEST_LOG
        echo "######################################################################" | tee -a $MD_TEST_LOG
        cd
		
        # Remove the temporary directory and lock file
        rm -rf $MD_TEST_BASE/tmp
        rm -f $MD_TEST_LOCK
	fi
fi

# Self destruct the script
rm -f /tmp/${MD_TEST_ARGS[0]}.${MD_TEST_ARGS[2]}.test-${MD_TEST_ARGS[1]}.thread-${MD_TEST_ARGS[3]}.sh