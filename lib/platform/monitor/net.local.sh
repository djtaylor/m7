#!/bin/bash

# Load the library index
source ~/lib/index.sh

# Target test ID and source plan
NM_TARGET_ID="$1"
NM_SOURCE_PLAN="$2"

while :
do
	
	# If all lock files have been cleared
	if [ -z "$(ls -A ~/lock/$NM_TARGET_ID/local)" ]; then
		break
	else
		sleep 2
	fi
done

# Create the test aggregation workspace
M7_TEST_WS="/tmp/m7.$NM_TARGET_ID"
mkdir -p $M7_TEST_WS

# Define the results file for the test
TEST_RESULT_FILE=~/output/$NM_TARGET_ID/local/results.xml

# Get the plan category
TEST_CATEGORY="$(xml "parse" "$NM_SOURCE_PLAN" "params/category/text()")"

# Open the plan XML block
TEST_SUMMARY_BLOCK="<plan>\n"
TEST_SUMMARY_BLOCK+="\t<category>$TEST_CATEGORY</category>\n"

# Aggregate the results of the test runs
for TEST_RESULT_PATH in $(find ~/output/$NM_TARGET_ID/local -mindepth 1 -maxdepth 1 -type d)
do
	
	# Get the test directory and ID
	TEST_RESULT_DIR="$(echo $TEST_RESULT_PATH | sed "s/^.*\/\([^\/]*$\)/\1/g")"
	TEST_RESULT_ID="$(echo $TEST_RESULT_PATH | sed "s/^.*\/test-\([0-9]*$\)/\1/g")"
	
	# Get the network test type
	TEST_NET_TYPE="$(xml "parse" "$NM_SOURCE_PLAN" "params/test[@id='$TEST_RESULT_ID']/type/text()")"
	
	# Open the test XML block
	TEST_SUMMARY_BLOCK+="\t<test id='$TEST_RESULT_ID'>\n"
	TEST_SUMMARY_BLOCK+="\t\t<type>$TEST_NET_TYPE</type>\n"
	
	case "$TEST_NET_TYPE" in
		
		"ping")
			
			# Get the ping count
			TEST_PING_COUNT="$(xml "parse" "$NM_SOURCE_PLAN" "params/test[@id='$TEST_RESULT_ID']/count/text()")"
				
			# Read the output logs for each ping
			for TEST_PING_LOG in $(find ~/output/$NM_TARGET_ID/local/$TEST_RESULT_DIR/tmp -type f)
			do
				
				# First get the exit code to see if the ping was successful
				TEST_PING_EXIT_CODE="$(cat $TEST_PING_LOG | grep "EXIT" | sed "s/^EXIT:'\([0-9]*\)'/\1/g")"
				
				# Get the target host and IP address
				TEST_PING_HOST="$(echo $TEST_PING_LOG | sed "s/^.*\/\([^\.]*\)\.log$/\1/g")"
				
				# If processing a supplementary host
				if [ -z  "$(sqlite3 ~/db/cluster.db "SELECT * FROM M7_Nodes WHERE Name='$TEST_PING_HOST';")" ]; then
					TEST_PING_HOST_TYPE="supplementary"
					TEST_PING_IP_ADDR="$(xml "parse" "$NM_SOURCE_PLAN" "params/hosts/host[@name='$TEST_PING_HOST']/text()")"
				else
					TEST_PING_HOST_TYPE="cluster"
					TEST_PING_IP_ADDR="$(sqlite3 ~/db/cluster.db "SELECT IPAddr FROM M7_Nodes WHERE Name='$TEST_PING_HOST';")"
				fi
				
				# If the ping has any exit code besides '0'
				if [ "$TEST_PING_EXIT_CODE" != "0" ]; then
					
					# Generate the host ping block
					TEST_SUMMARY_BLOCK+="\t\t<host name='$TEST_PING_HOST'>\n"
					TEST_SUMMARY_BLOCK+="\t\t\t<type>$TEST_PING_HOST_TYPE</type>\n"
					TEST_SUMMARY_BLOCK+="\t\t\t<ip>$TEST_PING_IP_ADDR</ip>\n"
					TEST_SUMMARY_BLOCK+="\t\t\t<exit>$TEST_PING_EXIT_CODE</exit>\n"
					TEST_SUMMARY_BLOCK+="\t\t</host>\n"
				else
					
					# Get the ping statistics
					TEST_PING_PKT_LOSS="$(cat $TEST_PING_LOG | grep "packet" | sed "s/^.*[ ]\([0-9]*\)%[ ].*$/\1/g")"
					TEST_PING_MIN_TIME="$(cat $TEST_PING_LOG | grep rtt | sed "s/^.*=[ ]\([0-9\.]*\)\/.*$/\1/g")"
					TEST_PING_AVG_TIME="$(cat $TEST_PING_LOG | grep rtt | sed "s/^.*=[ ][0-9\.]*\/\([0-9\.]*\)\/.*$/\1/g")"
					TEST_PING_MAX_TIME="$(cat $TEST_PING_LOG | grep rtt | sed "s/^.*=[ ][0-9\.]*\/[0-9\.]*\/\([0-9\.]*\)\/.*$/\1/g")"
					TEST_PING_AVG_DEV="$(cat $TEST_PING_LOG | grep rtt | sed "s/^.*=[ ][0-9\.]*\/[0-9\.]*\/[0-9\.]*\/\([0-9\.]*\)[ ].*$/\1/g")"
					
					# Generate the host ping block
					TEST_SUMMARY_BLOCK+="\t\t<host name='$TEST_PING_HOST'>\n"
					TEST_SUMMARY_BLOCK+="\t\t\t<type>$TEST_PING_HOST_TYPE</type>\n"
					TEST_SUMMARY_BLOCK+="\t\t\t<ip>$TEST_PING_IP_ADDR</ip>\n"
					TEST_SUMMARY_BLOCK+="\t\t\t<pktLoss unit='%'>$TEST_PING_PKT_LOSS</pktLoss>\n"
					TEST_SUMMARY_BLOCK+="\t\t\t<minTime unit='ms'>$TEST_PING_MIN_TIME</minTime>\n"
					TEST_SUMMARY_BLOCK+="\t\t\t<avgTime unit='ms'>$TEST_PING_AVG_TIME</avgTime>\n"
					TEST_SUMMARY_BLOCK+="\t\t\t<maxTime unit='ms'>$TEST_PING_MAX_TIME</maxTime>\n"
					TEST_SUMMARY_BLOCK+="\t\t\t<avgDev unit='ms'>$TEST_PING_AVG_DEV</avgDev>\n"
					TEST_SUMMARY_BLOCK+="\t\t</host>\n"
				fi
			done
			;;
			
		"traceroute")
			
			# Read the output logs for each traceroute
			for TEST_TROUTE_LOG in $(find ~/output/$NM_TARGET_ID/local/$TEST_RESULT_DIR/tmp -type f)
			do
				
				# First get the exit code to see if the traceroute was successful
				TEST_TROUTE_EXIT_CODE="$(cat $TEST_TROUTE_LOG | grep "EXIT" | sed "s/^EXIT:'\([0-9]*\)'/\1/g")"
				
				# Get the target host and IP address
				TEST_TROUTE_HOST="$(echo $TEST_TROUTE_LOG | sed "s/^.*\/\([^\.]*\)\.log$/\1/g")"
				
				# If processing a supplementary host
				if [ -z  "$(sqlite3 ~/db/cluster.db "SELECT * FROM M7_Nodes WHERE Name='$TEST_TROUTE_HOST';")" ]; then
					TEST_TROUTE_HOST_TYPE="supplementary"
					TEST_TROUTE_IP_ADDR="$(xml "parse" "$NM_SOURCE_PLAN" "params/hosts/host[@name='$TEST_TROUTE_HOST']/text()")"
				else
					TEST_TROUTE_HOST_TYPE="cluster"
					TEST_TROUTE_IP_ADDR="$(sqlite3 ~/db/cluster.db "SELECT IPAddr FROM M7_Nodes WHERE Name='$TEST_TROUTE_HOST';")"
				fi
				
				# If the traceroute has any exit code besides '0'
				if [ "$TEST_TROUTE_EXIT_CODE" != "0" ]; then
					
					# Generate the host traceroute block
					TEST_SUMMARY_BLOCK+="\t\t<host name='$TEST_TROUTE_HOST'>\n"
					TEST_SUMMARY_BLOCK+="\t\t\t<type>$TEST_TROUTE_HOST_TYPE</type>\n"
					TEST_SUMMARY_BLOCK+="\t\t\t<ip>$TEST_TROUTE_IP_ADDR</ip>\n"
					TEST_SUMMARY_BLOCK+="\t\t\t<exit>$TEST_TROUTE_EXIT_CODE</exit>\n"
					TEST_SUMMARY_BLOCK+="\t\t</host>\n"
				else
					
					# Generate the host traceroute block
					TEST_SUMMARY_BLOCK+="\t\t<host name='$TEST_TROUTE_HOST'>\n"
					TEST_SUMMARY_BLOCK+="\t\t\t<type>$TEST_TROUTE_HOST_TYPE</type>\n"
					TEST_SUMMARY_BLOCK+="\t\t\t<ip>$TEST_TROUTE_IP_ADDR</ip>\n"
					TEST_SUMMARY_BLOCK+="\t\t\t<hops>\n"
					
					# Generate entries for each hop
					while read TEST_TROUTE_HOP
					do
						if [ ! -z "$(echo "$TEST_TROUTE_HOP" | grep -e "^[0-9 ]*[ ].*$")" ]; then
                
                			# Get the hop number, IP, and time
							TEST_TROUTE_HOP_NUM="$(echo "$TEST_TROUTE_HOP" | sed "s/\(^[^ ]*\)[ ]*[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ].*$/\1/g")"
                			TEST_TROUTE_HOP_IP_ADDR="$(echo "$TEST_TROUTE_HOP" | sed "s/^[^ ]*[ ]*\([^ ]*\)[ ]*[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ].*$/\1/g")"
                			
                			# If the first hop is not empty
							if [ "$TEST_TROUTE_HOP_IP_ADDR" != "*" ]; then
								TEST_TROUTE_HOP_TRY="1"
								TEST_TROUTE_HOP_TIME="$(echo "$TEST_TROUTE_HOP" | sed "s/^[^ ]*[ ]*[^ ]*[ ]*\([^ ]*\)[ ]*[^ ]*[ ]*[^ ]*[ ].*$/\1/g")"
							else
								
								# Get the second IP address and time
								TEST_TROUTE_HOP_IP_ADDR="$(echo "$TEST_TROUTE_HOP" | sed "s/^[^ ]*[ ]*[^ ]*[ ]*\([^ ]*\)[ ]*[^ ]*[ ]*[^ ]*[ ].*$/\1/g")"
								
								# If the second hop is not empty
								if [ "$TEST_TROUTE_HOP_IP_ADDR" != "*" ]; then
									TEST_TROUTE_HOP_TRY="2"
									TEST_TROUTE_HOP_TIME="$(echo "$TEST_TROUTE_HOP" | sed "s/^[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*\([^ ]*\)[ ]*[^ ]*[ ].*$/\1/g")"
								else
									
									# Get the third IP address and time
									TEST_TROUTE_HOP_IP_ADDR="$(echo "$TEST_TROUTE_HOP" | sed "s/^[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*\([^ ]*\).*$/\1/g")"
									
									# If the third hop is not empty
									if [ "$TEST_TROUTE_HOP_IP_ADDR" != "*" ]; then
										TEST_TROUTE_HOP_TRY="3"
										TEST_TROUTE_HOP_TIME="$(echo "$TEST_TROUTE_HOP" | sed "s/^[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*\([^ ]*\)[ ].*$/\1/g")"
									else
										TEST_TROUTE_HOP_TRY="?"
										TEST_TROUTE_HOP_TIME="*"
									fi	
								fi
							fi
                			
                			# Define the hop XML block
							TEST_SUMMARY_BLOCK+="\t\t\t\t<hop number='$TEST_TROUTE_HOP_NUM'>\n"
							TEST_SUMMARY_BLOCK+="\t\t\t\t\t<try>$TEST_TROUTE_HOP_TRY</try>\n"
							TEST_SUMMARY_BLOCK+="\t\t\t\t\t<ip>$TEST_TROUTE_HOP_IP_ADDR</ip>\n"
							TEST_SUMMARY_BLOCK+="\t\t\t\t\t<time unit='ms'>$TEST_TROUTE_HOP_TIME</time>\n"
							TEST_SUMMARY_BLOCK+="\t\t\t\t</hop>\n"
        				fi
					done < $TEST_TROUTE_LOG			
					
					# Close the hops block
					TEST_SUMMARY_BLOCK+="\t\t\t</hops>\n"
					TEST_SUMMARY_BLOCK+="\t\t</host>\n"
				fi
			done
			;;
			
		"mtr")
			
			# Get the packet count
			TEST_MTR_COUNT="$(xml "parse" "$NM_SOURCE_PLAN" "params/test[@id='$TEST_RESULT_ID']/count/text()")"
				
			# Read the output logs for each MTR
			for TEST_MTR_LOG in $(find ~/output/$NM_TARGET_ID/local/$TEST_RESULT_DIR/tmp -type f)
			do
				
				# First get the exit code to see if the MTR was successful
				TEST_MTR_EXIT_CODE="$(cat $TEST_MTR_LOG | grep "EXIT" | sed "s/^EXIT:'\([0-9]*\)'/\1/g")"
				
				# Get the target host and IP address
				TEST_MTR_HOST="$(echo $TEST_MTR_LOG | sed "s/^.*\/\([^\.]*\)\.log$/\1/g")"
				
				# If processing a supplementary host
				if [ -z  "$(sqlite3 ~/db/cluster.db "SELECT * FROM M7_Nodes WHERE Name='$TEST_MTR_HOST';")" ]; then
					TEST_MTR_HOST_TYPE="supplementary"
					TEST_MTR_IP_ADDR="$(xml "parse" "$NM_SOURCE_PLAN" "params/hosts/host[@name='$TEST_MTR_HOST']/text()")"
				else
					TEST_MTR_HOST_TYPE="cluster"
					TEST_MTR_IP_ADDR="$(sqlite3 ~/db/cluster.db "SELECT IPAddr FROM M7_Nodes WHERE Name='$TEST_MTR_HOST';")"
				fi
				
				# If the ping has any exit code besides '0'
				if [ "$TEST_MTR_EXIT_CODE" != "0" ]; then
					
					# Generate the host MTR block
					TEST_SUMMARY_BLOCK+="\t\t<host name='$TEST_MTR_HOST'>\n"
					TEST_SUMMARY_BLOCK+="\t\t\t<type>$TEST_MTR_HOST_TYPE</type>\n"
					TEST_SUMMARY_BLOCK+="\t\t\t<ip>$TEST_MTR_IP_ADDR</ip>\n"
					TEST_SUMMARY_BLOCK+="\t\t\t<exit>$TEST_MTR_EXIT_CODE</exit>\n"
					TEST_SUMMARY_BLOCK+="\t\t</host>\n"
				else
					
					# Open the host MTR block
					TEST_SUMMARY_BLOCK+="\t\t<host name='$TEST_MTR_HOST'>\n"
					TEST_SUMMARY_BLOCK+="\t\t\t<type>$TEST_MTR_HOST_TYPE</type>\n"
					TEST_SUMMARY_BLOCK+="\t\t\t<ip>$TEST_MTR_IP_ADDR</ip>\n"
					TEST_SUMMARY_BLOCK+="\t\t\t<hops>\n"
					
					# Get the MTR statistics
					while read TEST_MTR_LOG_LINE
					do
						if [ ! -z "$(echo "$TEST_MTR_LOG_LINE" | grep -e "^[0-9\. ]*[ ].*$")" ]; then
							
							# Get the hop statistics
							TEST_MTR_HOP_COUNT="$(echo "$TEST_MTR_LOG_LINE" | sed "s/^[ ]*\([0-9]*\)\..*$/\1/g")"
							TEST_MTR_HOP_IP_ADDR="$(echo "$TEST_MTR_LOG_LINE" | sed "s/^[ ]*[0-9\.]*[ ]*\([0-9?\.]*\)[ ]*.*$/\1/g")"
							TEST_MTR_PKT_LOSS="$(echo "$TEST_MTR_LOG_LINE" | sed "s/^[ ]*[0-9\.]*[ ]*[0-9?\.]*[ ]*\([0-9\.]*\)%.*$/\1/g")"
							TEST_MTR_MIN_TIME="$(echo "$TEST_MTR_LOG_LINE" | sed "s/^[ ]*[0-9\.]*[ ]*[0-9?\.]*[ ]*[0-9\.]*%[ ]*[0-9]*[ ]*[0-9\.]*[ ]*[0-9\.]*[ ]*\([0-9\.]*\)[ ]*.*$/\1/g")"
							TEST_MTR_AVG_TIME="$(echo "$TEST_MTR_LOG_LINE" | sed "s/^[ ]*[0-9\.]*[ ]*[0-9?\.]*[ ]*[0-9\.]*%[ ]*[0-9]*[ ]*[0-9\.]*[ ]*\([0-9\.]*\)[ ]*.*$/\1/g")"
							TEST_MTR_MAX_TIME="$(echo "$TEST_MTR_LOG_LINE" | sed "s/^[ ]*[0-9\.]*[ ]*[0-9?\.]*[ ]*[0-9\.]*%[ ]*[0-9]*[ ]*[0-9\.]*[ ]*[0-9\.]*[ ]*[0-9\.]*[ ]*\([0-9\.]*\)[ ]*.*$/\1/g")"
							TEST_MTR_AVG_DEV="$(echo "$TEST_MTR_LOG_LINE" | sed "s/^[ ]*[0-9\.]*[ ]*[0-9?\.]*[ ]*[0-9\.]*%[ ]*[0-9]*[ ]*[0-9\.]*[ ]*[0-9\.]*[ ]*[0-9\.]*[ ]*[0-9\.]*[ ]*\([0-9\.]*$\)/\1/g")"
							
							# Generate the MTR hop entry
							TEST_SUMMARY_BLOCK+="\t\t\t\t<hop number='$TEST_MTR_HOP_COUNT'>\n"
							TEST_SUMMARY_BLOCK+="\t\t\t\t\t<ip>$TEST_MTR_HOP_IP_ADDR</ip>\n"
							TEST_SUMMARY_BLOCK+="\t\t\t\t\t<pktLoss unit='%'>$TEST_MTR_PKT_LOSS</pktLoss>\n"
							TEST_SUMMARY_BLOCK+="\t\t\t\t\t<minTime unit='ms'>$TEST_MTR_MIN_TIME</minTime>\n"
							TEST_SUMMARY_BLOCK+="\t\t\t\t\t<avgTime unit='ms'>$TEST_MTR_AVG_TIME</avgTime>\n"
							TEST_SUMMARY_BLOCK+="\t\t\t\t\t<maxTime unit='ms'>$TEST_MTR_MAX_TIME</maxTime>\n"
							TEST_SUMMARY_BLOCK+="\t\t\t\t\t<avgDev unit='ms'>$TEST_MTR_AVG_DEV</avgDev>\n"
							TEST_SUMMARY_BLOCK+="\t\t\t\t</hop>\n"
						fi
					done < $TEST_MTR_LOG
					TEST_SUMMARY_BLOCK+="\t\t\t</hops>\n"
					TEST_SUMMARY_BLOCK+="\t\t</host>\n"
				fi
			done
			
	esac
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
	log "info-proc" "Copying worker test results to director node:['~/output/$NM_TARGET_ID/worker/$TEST_WORKER_NAME.results.xml']..."
	scp -i $M7KEY -P $TEST_DIRECTOR_SSH_PORT -o StrictHostKeyChecking=no $TEST_RESULT_FILE \
	$TEST_DIRECTOR_USER@$TEST_DIRECTOR_IP_ADDR:~/output/$NM_TARGET_ID/worker/$TEST_WORKER_NAME.results.xml >> $M7LOG_XFER 2>&1
	
	# If the results failed to copy to the director node
	if [ "$?" != "0" ]; then
		log "info" "$FAILED"
		log "error" "Failed to copy worker test results to director node:['$TEST_DIRECTOR_USER@$TEST_DIRECTOR_IP_ADDR:$TEST_DIRECTOR_SSH_PORT']..."
	else
		log "info" "$SUCCESS"
		
		# Remove the lock file on the director node
		log "info-proc" "Removing lock file for worker node on director node..."
		ssh -i $M7KEY -p $TEST_DIRECTOR_SSH_PORT -o StrictHostKeyChecking=no $TEST_DIRECTOR_USER@$TEST_DIRECTOR_IP_ADDR "bash -c -l 'rm -f ~/lock/$NM_TARGET_ID/worker/$TEST_WORKER_ID'" >> $M7LOG_XFER 2>&1
		
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
rm -f /tmp/$NM_TARGET_ID.local.monitor.sh