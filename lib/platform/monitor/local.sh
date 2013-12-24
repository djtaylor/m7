#!/bin/bash

# Load the library index
source ~/lib/index.sh

# Target test ID and source plan
TM_TARGET_ID="$1"
TM_SOURCE_PLAN="$2"

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

# Get the plan category, protocol, and host
TEST_TARGET_CATEGORY="$(xml "parse" "$TM_SOURCE_PLAN" "params/category/text()")"
TEST_TARGET_PROTO="$(xml "parse" "$TM_SOURCE_PLAN" "params/proto/text()")"
TEST_TARGET_HOST="$(xml "parse" "$TM_SOURCE_PLAN" "params/host/text()")"

# Open the plan XML block
TEST_SUMMARY_BLOCK="<plan>\n"
TEST_SUMMARY_BLOCK+="\t<category>$TEST_TARGET_CATEGORY</category>\n"

# Aggregate the results of the test runs
for TEST_RESULT_PATH in $(find ~/output/$TM_TARGET_ID/local -mindepth 1 -maxdepth 1 -type d)
do
	
	# Get the test directory and ID
	TEST_RESULT_DIR="$(echo $TEST_RESULT_PATH | sed "s/^.*\/\([^\/]*$\)/\1/g")"
	TEST_RESULT_ID="$(echo $TEST_RESULT_PATH | sed "s/^.*\/test-\([0-9]*$\)/\1/g")"
	
	# Get the target file URL and download type
	TEST_TARGET_PATH="$(xml "parse" "${TEST_EXEC_ARGS[0]}" "params/test[@id='$TEST_RESULT_ID']/path/text()")"
	TEST_TARGET_TYPE="$(xml "parse" "${TEST_EXEC_ARGS[0]}" "params/test[@id='$TEST_RESULT_ID']/type/text()")"
	TEST_TARGET_URL="$TEST_TARGET_PROTO://$TEST_TARGET_HOST/$TEST_TARGET_PATH"
	
	# Open the test XML block
	TEST_SUMMARY_BLOCK+="\t<test id='$TEST_RESULT_ID'>\n"
	TEST_SUMMARY_BLOCK+="\t\t<filetype>$TEST_TARGET_TYPE</filetype>\n"
	
	# Print either a single file or list of files
	if [ "$TEST_TARGET_TYPE" = "single-download" ]; then
		TEST_SUMMARY_BLOCK+="\t\t<fileurl>$TEST_TARGET_URL</fileurl>\n"
	fi
	if [ "$TEST_TARGET_TYPE" = "multi-download" ]; then
		
		# Build an array of all files to download
		TEST_MULTI_FILES_WORKSPACE="/tmp/$TM_TARGET_ID.$TEST_RESULT_ID.multi"
		echo "cat //plan/params/test[@id='$TEST_RESULT_ID']/paths/path" | xmllint --shell $TM_SOURCE_PLAN > $TEST_MULTI_FILES_WORKSPACE
		declare TEST_MULTI_FILES_ARRAY
		while read TEST_MULTI_FILE
		do
			TEST_MULTI_FILES_ARRAY+=("$TEST_TARGET_PROTO://$TEST_TARGET_HOST$(echo $TEST_MULTI_FILE | sed "s/^<path>\([^<]*\)<\/path>$/\1/g")")
		done < $TEST_EXEC_MULTI_WORKSPACE
		
		# Print the files block
		TEST_SUMMARY_BLOCK+="\t\t<files>\n"
		for TEST_MULTI_FILE in "${TEST_MULTI_FILES_ARRAY[@]}"
		do
			TEST_SUMMARY_BLOCK+="\t\t\t<file>$TEST_MULTI_FILE</file>\n"
		done
		TEST_SUMMARY_BLOCK+="\t\t</files>\n"
	fi
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
		
		# If downloading a single file
		if [ "$TEST_TARGET_TYPE" = "single-file" ]; then
			
			# Process the summary lines and build the results XML file
			THREAD_SAMPLE_COUNT="0"
			while read THREAD_SUMMARY_LINE
			do
				let THREAD_SAMPLE_COUNT++
				
				# Grab the average download speed and time
				THREAD_AVG_SPEED="$(curl_parse "avgSpeed" "$THREAD_SUMMARY_LINE")"
				THREAD_DL_TIME="$(curl_parse "dlTime" "$THREAD_SUMMARY_LINE")"
				
				# Calculate and store the average download speed and time
				THREAD_AVG_SPEED_ARRAY+=("$(calc "xferSpeed" "$THREAD_AVG_SPEED")")
				THREAD_DL_TIME_ARRAY+=("$(calc "dlTime" "$THREAD_DL_TIME")")
				
				# Define the sample summary block
				TEST_SUMMARY_BLOCK+="\t\t\t\t\t<sample-$THREAD_SAMPLE_COUNT>\n"
				TEST_SUMMARY_BLOCK+="\t\t\t\t\t\t<speed unit='kbps'>$THREAD_AVG_SPEED_RAW</avgSpeed>\n"
				TEST_SUMMARY_BLOCK+="\t\t\t\t\t\t<time unit='seconds'>$THREAD_DL_TIME_RAW</dlTime>\n"
				TEST_SUMMARY_BLOCK+="\t\t\t\t\t</sample-$THREAD_SAMPLE_COUNT>\n"
			done < $THREAD_SUMMARY_WS
		fi
		
		# If downloading multiple files
		if [ "$TEST_TARGET_TYPE" = "multi-file" ]; then
			
			# Get the total files in each sample
			THREAD_SAMPLE_FILE_COUNT="${#TEST_MULTI_FILES_ARRAY[@]}"
			
			# Initialize the speed and time arrays for the current sample
			declare -a THREAD_SAMPLE_AVG_SPEED_ARRAY
			declare -a THREAD_SAMPLE_DL_TIME_ARRAY
			
			# Build the averages for each sample group
			THREAD_SAMPLE_COUNT=1
			THREAD_FILE_COUNT=0
			while read THREAD_SUMMARY_LINE
			do
				let THREAD_FILE_COUNT++
				
				# If we have reached the end of the sample
				if [ "$THREAD_FILE_COUNT" = "$THREAD_SAMPLE_FILE_COUNT" ]; then
					THREAD_FILE_COUNT=0
					let THREAD_SAMPLE_COUNT++
					
					# Calculate and store the average speed and download time
					TEST_AVG_SPEED_ARRAY+=("$(calc "arrayAvg" "THREAD_SAMPLE_AVG_SPEED_ARRAY[@]")")
					TEST_DL_TIME_ARRAY+=("$(calc "arrayAvg" "THREAD_SAMPLE_DL_TIME_ARRAY[@]")")
					
					# Reset the thread sample arrays
					declare -a THREAD_SAMPLE_AVG_SPEED_ARRAY
					declare -a THREAD_SAMPLE_DL_TIME_ARRAY
				else
					
					# Grab the average download speed and time
					THREAD_SAMPLE_AVG_SPEED="$(curl_parse "avgSpeed" "$THREAD_SUMMARY_LINE")"
					THREAD_SAMPLE_DL_TIME="$(curl_parse "dlTime" "$THREAD_SUMMARY_LINE")"
					
					# Calculate and store the average download speed and time
					THREAD_SAMPLE_AVG_SPEED_ARRAY+=("$(calc "xferSpeed" "$THREAD_SAMPLE_AVG_SPEED")")
					THREAD_SAMPLE_DL_TIME_ARRAY+=("$(calc "dlTime" "$THREAD_SAMPLE_DL_TIME")")
				fi
			done < $THREAD_SUMMARY_WS
		fi
		
		# Close the samples block
		TEST_SUMMARY_BLOCK+="\t\t\t\t</samples>\n"
		
		# Calculate and store the average download speed and time
		TEST_AVG_SPEED_ARRAY+=("$(calc "arrayAvg" "THREAD_AVG_SPEED_ARRAY[@]")")
		TEST_DL_TIME_ARRAY+=("$(calc "arrayAvg" "THREAD_DL_TIME_ARRAY[@]")")
		
		# Generate the thread averages block
		TEST_SUMMARY_BLOCK+="\t\t\t\t<average>\n"
		TEST_SUMMARY_BLOCK+="\t\t\t\t\t<speed unit='kbps'>$THREAD_AVG_SPEED_RESULT</speed>\n"
		TEST_SUMMARY_BLOCK+="\t\t\t\t\t<time unit='seconds'>$THREAD_DL_TIME_RESULT</time>\n"
		TEST_SUMMARY_BLOCK+="\t\t\t\t</average>\n"
		
		# Close the thread block
		TEST_SUMMARY_BLOCK+="\t\t\t</thread-$THREAD_OUTPUT_ID>\n"
	done
	
	# Find and store the average test value for download speed and time
	TEST_AVG_SPEED_RESULT="$(calc "arrayAvg" "TEST_AVG_SPEED_ARRAY[@]")"
	TEST_DL_TIME_RESULT="$(calc "arrayAvg" "TEST_DL_TIME_ARRAY[@]")"
	
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
	
	# Get the director node name, user, SSH port, and IP address
	TEST_DIRECTOR_NAME="$(sqlite3 ~/db/cluster.db "SELECT Name FROM M7_Nodes WHERE Type='director';")"
	TEST_DIRECTOR_USER="$(sqlite3 ~/db/cluster.db "SELECT User FROM M7_Nodes WHERE Type='director';")"
	TEST_DIRECTOR_SSH_PORT="$(sqlite3 ~/db/cluster.db "SELECT SSHPort FROM M7_Nodes WHERE Type='director';")"
	TEST_DIRECTOR_IP_ADDR="$(sqlite3 ~/db/cluster.db "SELECT IPAddr FROM M7_Nodes WHERE Type='director';")"
	
	# Get the local worker name and ID
	TEST_WORKER_NAME="$(sqlite3 ~/db/cluster.db "SELECT Name FROM M7_Nodes WHERE Name='$(hostname -s)';")"
	TEST_WORKER_ID="$(sqlite3 ~/db/cluster.db "SELECT Id FROM M7_Nodes WHERE Name='$(hostname -s)';")"
	
	# Copy the results to the director node
	log "info-proc" "Copying worker test results to director node:['~/output/$TM_TARGET_ID/worker/$TEST_WORKER_NAME.results.xml']..."
	scp -i $M7KEY -P $TEST_DIRECTOR_SSH_PORT -o StrictHostKeyChecking=no $TEST_RESULT_FILE \
	$TEST_DIRECTOR_USER@$TEST_DIRECTOR_IP_ADDR:~/output/$TM_TARGET_ID/worker/$TEST_WORKER_NAME.results.xml &>> $M7LOG_XFER
	
	# If the results failed to copy to the director node
	if [ "$?" != "0" ]; then
		log "info" "$FAILED"
		log "error" "Failed to copy worker test results to director node:['$TEST_DIRECTOR_USER@$TEST_DIRECTOR_IP_ADDR:$TEST_DIRECTOR_SSH_PORT']..."
	else
		log "info" "$SUCCESS"
		
		# Remove the lock file on the director node
		log "info-proc" "Removing lock file for worker node on director node..."
		ssh -i $M7KEY -p $TEST_DIRECTOR_SSH_PORT -o StrictHostKeyChecking=no $TEST_DIRECTOR_USER@$TEST_DIRECTOR_IP_ADDR rm -f ~/lock/$TM_TARGET_ID/worker/$TEST_WORKER_ID &>> $M7LOG_XFER
		
		# If the lock file was not removed
		if [ "$?" != "0" ]; then
			log "info" "$FAILED"
			log "error" "Failed to remove lock file for worker node on director node:['$TEST_DIRECTOR_USER@$TEST_DIRECTOR_IP_ADDR:$TEST_DIRECTOR_SSH_PORT']..."
		else
			log "info" "$SUCCESS"
		fi
	fi
fi

# Self destruct the monitor script and destroy the workspace
rm -rf $M7_TEST_WS
rm -f /tmp/$TM_TARGET_ID.local.monitor.sh