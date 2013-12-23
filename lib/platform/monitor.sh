#!/bin/bash

# Load the library index
source ~/lib/index.sh

# Target test ID
TM_TARGET_ID="$1"

while :
do
	
	# If all lock files have been cleared
	if [ -z "$(ls -A ~/lock/$TM_TARGET_ID/local)" ]; then
		break
	else
		sleep 2
	fi
	
done

# Create the test aggregation workspace
M7_TEST_WS="/tmp/m7.$TM_TARGET_ID"
mkdir -p $M7_TEST_WS

# Define the results file for the test
TEST_RESULT_FILE=~/output/$TM_TARGET_ID/local/results.xml

# Open the plan XML block
TEST_SUMMARY_BLOCK="<plan>\n"

# Need to update the find command to only return the first level of subdirectories

# Aggregate the results of the test runs
for TEST_RESULT_PATH in $(find ~/output/$TM_TARGET_ID/local -mindepth 1 -maxdepth 1 -type d)
do
	
	# Get the test directory and ID
	TEST_RESULT_DIR="$(echo $TEST_RESULT_PATH | sed "s/^.*\/\([^\/]*$\)/\1/g")"
	TEST_RESULT_ID="$(echo $TEST_RESULT_PATH | sed "s/^.*\/test-\([0-9]*$\)/\1/g")"
	
	# Open the test XML block
	TEST_SUMMARY_BLOCK+="\t<test id='$TEST_RESULT_ID'>\n"
	TEST_SUMMARY_BLOCK+="\t\t<threads>\n"
	
	# Initialize the test average result arrays
	declare -a TEST_AVG_SPEED_ARRAY
	declare -a TEST_DL_TIME_ARRAY
	
	# Collect the output of each thread
	for THREAD_OUTPUT_PATH in $(find ~/output/$TM_TARGET_ID/local/$TEST_RESULT_DIR/thread-*/output.log -type f)
	do
		
		# Get the thread tag and ID
		THREAD_OUTPUT_TAG="$(echo $THREAD_OUTPUT_PATH | sed "s/^.*\/\(thread-[0-9]*\)\/.*$/\1/g")"
		THREAD_OUTPUT_ID="$(echo $THREAD_OUTPUT_TAG | sed "s/^thread-\([0-9]*$\)/\1/g")"
		
		# Open the thread XML block
		TEST_SUMMARY_BLOCK+="\t\t\t<thread-$THREAD_OUTPUT_ID>\n"
		
		# Build aworkspace of the summary lines in each output log
		THREAD_SUMMARY_WS="$M7_TEST_WS/test-${TEST_RESULT_ID}.$THREAD_OUTPUT_ID" && touch $THREAD_SUMMARY_WS
		cat $THREAD_OUTPUT_PATH | grep "Closing" | sed "s/^.*\o015\(.*$\)/\1/g" > $THREAD_SUMMARY_WS
		
		# Initialize the property averages arrays
		declare -a THREAD_AVG_SPEED_ARRAY
		declare -a THREAD_DL_TIME_ARRAY
		
		# Open the samples block
		TEST_SUMMARY_BLOCK+="\t\t\t\t<samples>\n"
		
		# Process the summary lines and build the results XML file
		THREAD_SAMPLE_COUNT="0"
		while read THREAD_SUMMARY_LINE
		do
			
			# Iterate the sample counter
			let THREAD_SAMPLE_COUNT++
			
			# Grab the average download speed and time
			THREAD_AVG_SPEED="$(curl_parse "avgSpeed" "$THREAD_SUMMARY_LINE")"
			THREAD_DL_TIME="$(curl_parse "dlTime" "$THREAD_SUMMARY_LINE")"
			
			# Get the average speed without unit
			THREAD_AVG_SPEED_RAW="$(echo $THREAD_AVG_SPEED | sed "s/\(^[0-9]*\).*$/\1/g")"
			THREAD_AVG_SPEED_ARRAY+=("$THREAD_AVG_SPEED_RAW")
			
			# Get the average download time in seconds
			THREAD_DL_TIME_RAW="$(echo "$THREAD_DL_TIME" | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')"
			THREAD_DL_TIME_ARRAY+=("$THREAD_DL_TIME_RAW")
			
			# Define the sample summary block
			TEST_SUMMARY_BLOCK+="\t\t\t\t\t<sample-$THREAD_SAMPLE_COUNT>\n"
			TEST_SUMMARY_BLOCK+="\t\t\t\t\t\t<speed unit='kbps'>$THREAD_AVG_SPEED_RAW</avgSpeed>\n"
			TEST_SUMMARY_BLOCK+="\t\t\t\t\t\t<time unit='seconds'>$THREAD_DL_TIME_RAW</dlTime>\n"
			TEST_SUMMARY_BLOCK+="\t\t\t\t\t</sample-$THREAD_SAMPLE_COUNT>\n"
		done < $THREAD_SUMMARY_WS
		
		# Close the samples block
		TEST_SUMMARY_BLOCK+="\t\t\t\t</samples>\n"
		
		# Find the average value for speed
		THREAD_AVG_SPEED_COUNT="${#THREAD_AVG_SPEED_ARRAY[@]}"
		THREAD_AVG_SPEED_SUM=0
		for THREAD_AVG_SPEED_VAL in "${THREAD_AVG_SPEED_ARRAY[@]}"
		do
			THREAD_AVG_SPEED_SUM="$(expr $THREAD_AVG_SPEED_SUM + $THREAD_AVG_SPEED_VAL)"
		done
		THREAD_AVG_SPEED_RESULT="$(echo "$THREAD_AVG_SPEED_SUM/$THREAD_AVG_SPEED_COUNT" | bc)"
		TEST_AVG_SPEED_ARRAY+=("$THREAD_AVG_SPEED_RESULT")

		# Find the average value for download time
		THREAD_DL_TIME_COUNT="${#THREAD_DL_TIME_ARRAY[@]}"
		THREAD_DL_TIME_SUM=0
		for THREAD_DL_TIME_VAL in "${THREAD_DL_TIME_ARRAY[@]}"
		do
			THREAD_DL_TIME_SUM="$(expr $THREAD_DL_TIME_SUM + $THREAD_DL_TIME_VAL)"
		done
		THREAD_DL_TIME_RESULT="$(echo "$THREAD_DL_TIME_SUM/$THREAD_DL_TIME_COUNT" | bc)"
		TEST_DL_TIME_ARRAY+=("$THREAD_DL_TIME_RESULT")
		
		# Generate the thread averages block
		TEST_SUMMARY_BLOCK+="\t\t\t\t<average>\n"
		TEST_SUMMARY_BLOCK+="\t\t\t\t\t<speed unit='kbps'>$THREAD_AVG_SPEED_RESULT</speed>\n"
		TEST_SUMMARY_BLOCK+="\t\t\t\t\t<time unit='seconds'>$THREAD_DL_TIME_RESULT</time>\n"
		TEST_SUMMARY_BLOCK+="\t\t\t\t</average>\n"
		
		# Close the thread block
		TEST_SUMMARY_BLOCK+="\t\t\t</thread-$THREAD_OUTPUT_ID>\n"
	done
	
	# Find the test average value for speed
	TEST_AVG_SPEED_COUNT="${#TEST_AVG_SPEED_ARRAY[@]}"
	TEST_AVG_SPEED_SUM=0
	for TEST_AVG_SPEED_VAL in "${TEST_AVG_SPEED_ARRAY[@]}"
	do
		TEST_AVG_SPEED_SUM="$(expr $TEST_AVG_SPEED_SUM + $TEST_AVG_SPEED_VAL)"
	done
	TEST_AVG_SPEED_RESULT="$(echo "$TEST_AVG_SPEED_SUM/$TEST_AVG_SPEED_COUNT" | bc)"

	# Find the test average value for download time
	TEST_DL_TIME_COUNT="${#TEST_DL_TIME_ARRAY[@]}"
	TEST_DL_TIME_SUM=0
	for TEST_DL_TIME_VAL in "${TEST_DL_TIME_ARRAY[@]}"
	do
		TEST_DL_TIME_SUM="$(expr $THREAD_DL_TIME_SUM + $THREAD_DL_TIME_VAL)"
	done
	TEST_DL_TIME_RESULT="$(echo "$TEST_DL_TIME_SUM/$TEST_DL_TIME_COUNT" | bc)"
	
	# Generate the test averages block
	TEST_SUMMARY_BLOCK+="\t\t\t<average>\n"
	TEST_SUMMARY_BLOCK+="\t\t\t\t<speed unit='kbps'>$TEST_AVG_SPEED_RESULT</speed>\n"
	TEST_SUMMARY_BLOCK+="\t\t\t\t<time unit='seconds'>$TEST_DL_TIME_RESULT</time>\n"
	TEST_SUMMARY_BLOCK+="\t\t\t</average>\n"
	
	# Close the test XML block
	TEST_SUMMARY_BLOCK+="\t\t</threads>\n"
	TEST_SUMMARY_BLOCK+="\t</test>\n"
done

# Close the test plan block
TEST_SUMMARY_BLOCK+="</plan>"

# Create the test plan results file
echo -e "$TEST_SUMMARY_BLOCK" > $TEST_RESULT_FILE

# If running on a worker node
if [ ! -z "$(sqlite3 ~/db/cluster.db "SELECT * FROM M7_Nodes WHERE Type='worker' AND Name='$(hostname -s)';")" ]; then
	
	# Get the director node user, SSH port, and IP address
	TEST_DIRECTOR_USER="$(sqlite3 ~/db/cluster.db "SELECT User FROM M7_Nodes WHERE Type='director';")"
	TEST_DIRECTOR_SSH_PORT="$(sqlite3 ~/db/cluster.db "SELECT SSHPort FROM M7_Nodes WHERE Type='director';")"
	TEST_DIRECTOR_IP_ADDR="$(sqlite3 ~/db/cluster.db "SELECT IPAddr FROM M7_Nodes WHERE Type='director';")"
	
	# Get the local worker ID
	TEST_WORKER_ID="$(sqlite3 ~/db/cluster.db "SELECT Id FROM M7_Nodes WHERE Name='$(hostname -s)';")"
	
	# Copy the results to the director node
	scp -i $M7KEY -P $TEST_DIRECTOR_SSH_PORT -o StrictHostKeyChecking=no $TEST_RESULT_FILE $TEST_DIRECTOR_USER@$TEST_DIRECTOR_IP_ADDR:~/output/$TM_TARGET_ID/worker/$TEST_WORKER_ID.results.xml
	if [ "$?" != "0" ]; then
		log "error" "Failed to copy worker test results to director node..."
	else
		log "info" "Copying worker test results to director node: '~/output/$TM_TARGET_ID/worker/$TEST_WORKER_ID.results.xml'"
		
		# Remove the lock file on the director node
		ssh -i $M7KEY -p $TEST_DIRECTOR_SSH_PORT -o StrictHostKeyChecking=no $TEST_DIRECTOR_USER@$TEST_DIRECTOR_IP_ADDR rm -f ~/lock/$TM_TARGET_ID/worker/$TEST_WORKER_ID
		if [ "$?" != "0" ]; then
			log "error" "Failed to remove lock file for worker node on director node..."
		else
			log "info" "Removing lock file for worker node on director node..."
		fi
	fi
fi

# Self destruct the monitor script and destroy the workspace
rm -rf $M7_TEST_WS
rm -f /tmp/$TM_TARGET_ID.monitor.sh