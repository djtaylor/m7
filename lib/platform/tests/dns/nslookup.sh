#!/bin/bash

# Load the library index
source ~/lib/index.sh

# DNS Test - NSLookup
#
# !arg0		'Test plan ID'
# !arg1		'Test definition ID'
# !arg2		'Test thread number'
# !arg3 	'Test plan category'
# !arg4     'Test category type'
# !arg5		'Number of samples to run'
# !arg6		'Test plan file'
NSL_TEST_ARGS=(\
"{TEST_PLAN_ID}"
"{TEST_DEF_ID}"
"{TEST_THREAD_NUM}"
"{TEST_CAT}"
"{TEST_CAT_TYPE}"
"{TEST_SAMPLES}"
"{TEST_TARGET_NS}"
"{TEST_PLAN}")

# Set the base directory from the plan ID, test ID, and thread number
NSL_TEST_BASE=~/output/${NSL_TEST_ARGS[0]}/local/test-${NSL_TEST_ARGS[1]}
mkdir -p $NSL_TEST_BASE/tmp

# Generate the test lockfile directory and create the test thread lockfile
NSL_TEST_LOCK_DIR=~/lock/${NSL_TEST_ARGS[0]}/local
NSL_TEST_LOCK="$NSL_TEST_LOCK_DIR/test-${NSL_TEST_ARGS[1]}"
mkdir -p $NSL_TEST_LOCK_DIR
touch $NSL_TEST_LOCK

# Set the test output log file
NSL_TEST_LOG="$NSL_TEST_BASE/output.log"

# Start the test loop
echo "######################################################################" | tee $NSL_TEST_LOG
echo "INITIALIZING TEST:   '${NSL_TEST_ARGS[3]}':'${NSL_TEST_ARGS[4]}'" | tee -a $NSL_TEST_LOG
echo "> Test Thread: '${NSL_TEST_ARGS[2]}'" | tee -a $NSL_TEST_LOG
echo "> Test Samples: '${NSL_TEST_ARGS[5]}'" | tee -a $NSL_TEST_LOG
echo "> Test Log File:     '$NSL_TEST_LOG'" | tee -a $NSL_TEST_LOG
echo "######################################################################" | tee -a $NSL_TEST_LOG

# Initialize the samples counter
NSL_SAMPLE_COUNT="0"

# Build an array of the hosts to lookup
NSL_LOOKUP_HOSTS=( `echo "cat //plan/params/hosts/host/text()" | xmllint --shell "${NSL_TEST_ARGS[7]}" | grep -e "^[a-zA-Z0-9].*$"` )

while [ "${NSL_TEST_ARGS[5]}" -gt "$NSL_SAMPLE_COUNT" ]
do
	echo "----------------------------------------------------------------------" | tee -a $NSL_TEST_LOG
	echo "RUNNING TEST SAMPLE('$NSL_SAMPLE_COUNT')" | tee -a $NSL_TEST_LOG
    echo "----------------------------------------------------------------------" | tee -a $NSL_TEST_LOG
	for NSL_LOOKUP_HOST in "${NSL_LOOKUP_HOSTS[@]}"
	do
		cd $NSL_TEST_BASE/tmp
		{ time nslookup $NSL_LOOKUP_HOST ${NSL_TEST_ARGS[6]}; } &>> $NSL_TEST_LOG
	done
	let NSL_SAMPLE_COUNT++
done

# Run nslookup on each node in the hosts list

echo "######################################################################" | tee -a $NSL_TEST_LOG
echo "TEST COMPLETED" | tee -a $NSL_TEST_LOG
echo "######################################################################" | tee -a $NSL_TEST_LOG
	
# Remove the lock file
rm -f $NSL_TEST_LOCK

# Self destruct the script
rm -f /tmp/${NSL_TEST_ARGS[0]}.${NSL_TEST_ARGS[2]}.test-${NSL_TEST_ARGS[1]}.sh